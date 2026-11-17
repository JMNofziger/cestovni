/// Headless sign-in session for Android (CES-87).
///
/// The sign-in screen is CES-89. This type exchanges a one-time login
/// code, holds tokens, refreshes, and signs out. It calls only this
/// API. It does not embed a Google SDK and it does not decode the
/// access token. Expiry comes from `expires_in` on the session body.
///
/// The refresh token and `user_id` live in [TokenStore] (Android
/// Keystore via [FlutterSecureTokenStore]). The access token lives in
/// memory and is gone when the process dies.
///
/// [beforeSignedIn] runs before `signedIn` is reported. CES-77 uses it
/// to rebind `settings.id` to `user_id` before the flush worker can
/// send. The access token argument is the token just issued. It is
/// not read from this session, so the hook does not call [bearer].
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../db/repositories/settings_repository.dart';
import 'token_store.dart';

const refreshTokenKey = 'cestovni.refresh_token';
const userIdKey = 'cestovni.user_id';

const _refreshSkew = Duration(seconds: 60);

/// `signedOut | signedIn(userId, email) | refreshing`.
sealed class AuthState {
  const AuthState();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class Refreshing extends AuthState {
  const Refreshing();
}

class SignedIn extends AuthState {
  const SignedIn(this.userId, this.email);

  final String userId;
  final String? email;
}

/// Transport failure talking to an auth route. The session is kept.
class AuthNetworkException implements Exception {
  const AuthNetworkException(this.message);
  final String message;

  @override
  String toString() => 'AuthNetworkException: $message';
}

/// Auth route returned a status this client will not treat as success.
/// The message never includes a token, code, or response body.
class AuthHttpException implements Exception {
  const AuthHttpException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'AuthHttpException($statusCode): $message';
}

class _SessionBody {
  const _SessionBody({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String userId;
  final String? email;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}

/// `(userId, accessToken) -> rebind`. Awaited before [SignedIn].
typedef BeforeSignedIn =
    Future<void> Function(String userId, String accessToken);

class AuthSession {
  AuthSession({
    required String baseUrl,
    TokenStore? store,
    http.Client? httpClient,
    DateTime Function()? clock,
    this.beforeSignedIn,
  }) : _baseUrl = _trimSlash(baseUrl),
       _store = store ?? FlutterSecureTokenStore(),
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _clock = clock ?? DateTime.now {
    ready = _restore();
  }

  /// Runs after tokens for this sign-in are stored and before [SignedIn]
  /// is emitted. [AccountMismatch] clears the session and is rethrown.
  /// Any other error leaves the tokens in place and skips [SignedIn]
  /// until a later [bearer] call succeeds.
  final BeforeSignedIn? beforeSignedIn;

  final String _baseUrl;
  final TokenStore _store;
  final http.Client _http;
  final bool _ownsHttp;
  final DateTime Function() _clock;
  final _states = StreamController<AuthState>.broadcast();

  /// Completes after secure storage has been read once.
  late final Future<void> ready;

  AuthState _state = const SignedOut();
  Future<void>? _refreshFlight;
  int _epoch = 0;

  String? _accessToken;
  DateTime? _accessExpiresAt;
  String? _refreshToken;
  String? _userId;
  String? _email;
  String? _reboundFor;
  Future<void>? _rebindFlight;

  AuthState get state => _state;

  Stream<AuthState> get stateStream => _states.stream;

  /// `POST /api/v1/auth/google/exchange` with `{code}`.
  ///
  /// Stores the refresh token and `user_id`, keeps the access token in
  /// memory, and emits [SignedIn]. Returns `user_id`.
  Future<String> exchange(String code) async {
    await ready;
    final resp = await _post('/api/v1/auth/google/exchange', {'code': code});
    if (resp.statusCode != 200) {
      throw AuthHttpException(resp.statusCode, 'exchange failed');
    }
    final session = _parseSession(resp.body);
    await _apply(session, _epoch);
    return session.userId;
  }

  /// `POST /api/v1/auth/logout`, then drop local tokens even if the
  /// call fails. Emits [SignedOut].
  Future<void> signOut() async {
    await ready;
    _epoch++;
    final token = _refreshToken;
    if (token != null && token.isNotEmpty) {
      try {
        await _post('/api/v1/auth/logout', {'refresh_token': token});
      } catch (_) {
        // Local sign-out still proceeds.
      }
    }
    await _clear(emit: true);
  }

  /// Access token, or null when there is no session.
  ///
  /// Refreshes first when the access token is missing or expires within
  /// 60 seconds. A network failure throws [AuthNetworkException] and
  /// leaves the session in place.
  Future<String?> bearer() async {
    await ready;
    if (_refreshToken == null || _refreshToken!.isEmpty) return null;
    final token = _accessToken;
    final exp = _accessExpiresAt;
    final stale =
        token == null ||
        exp == null ||
        !exp.isAfter(_clock().add(_refreshSkew));
    if (stale) {
      await refreshOnce();
    } else {
      final userId = _userId;
      final access = _accessToken;
      if (userId != null && access != null) {
        await _rebindIfNeeded(userId, access);
        if (_reboundFor == userId && state is! SignedIn) {
          await _emit(SignedIn(userId, _email));
        }
      }
    }
    if (_refreshToken == null || _refreshToken!.isEmpty) return null;
    return _accessToken;
  }

  /// One refresh in flight at a time. Concurrent callers share it.
  ///
  /// Success stores the rotated refresh token and the new access token.
  /// `401 refresh_invalid` clears the session and emits [SignedOut].
  /// A network failure throws and does not clear the session.
  Future<void> refreshOnce() {
    final existing = _refreshFlight;
    if (existing != null) return existing;
    final run = _refreshBody();
    _refreshFlight = run;
    return run.whenComplete(() {
      if (identical(_refreshFlight, run)) _refreshFlight = null;
    });
  }

  void close() {
    if (_ownsHttp) _http.close();
    _states.close();
  }

  Future<void> _refreshBody() async {
    await ready;
    final token = _refreshToken;
    if (token == null || token.isEmpty) return;
    final epoch = _epoch;
    await _emit(const Refreshing());
    final http.Response resp;
    try {
      resp = await _post('/api/v1/auth/refresh', {'refresh_token': token});
    } on AuthNetworkException {
      if (epoch == _epoch) await _emitRestored();
      rethrow;
    }
    if (epoch != _epoch) return;
    if (resp.statusCode == 401 && _isRefreshInvalid(resp)) {
      _epoch++;
      await _clear(emit: true);
      return;
    }
    if (resp.statusCode != 200) {
      await _emitRestored();
      if (resp.statusCode >= 500) {
        throw AuthNetworkException('refresh status ${resp.statusCode}');
      }
      throw AuthHttpException(resp.statusCode, 'refresh failed');
    }
    await _apply(_parseSession(resp.body), epoch);
  }

  Future<void> _restore() async {
    try {
      final refresh = await _store.read(refreshTokenKey);
      final userId = await _store.read(userIdKey);
      if (_epoch != 0 || _refreshToken != null) return;
      if (refresh == null ||
          refresh.isEmpty ||
          userId == null ||
          userId.isEmpty) {
        await _emit(const SignedOut());
        return;
      }
      _refreshToken = refresh;
      _userId = userId;
      // A stored session has no access token yet. signedIn waits until
      // refresh produces one and [beforeSignedIn] finishes, which
      // [bearer] does before it returns that token. With no hook the
      // CES-87 path still reports the stored user immediately.
      if (beforeSignedIn == null) {
        await _emit(SignedIn(userId, null));
      }
    } catch (_) {
      debugPrint('AuthSession: secure storage unavailable');
      await _emit(const SignedOut());
    }
  }

  Future<void> _apply(_SessionBody session, int epoch) async {
    if (epoch != _epoch) return;
    await _store.write(userIdKey, session.userId);
    await _store.write(refreshTokenKey, session.refreshToken);
    if (epoch != _epoch) {
      await _clear(emit: true);
      return;
    }
    _accessToken = session.accessToken;
    _accessExpiresAt = _clock().add(Duration(seconds: session.expiresIn));
    _refreshToken = session.refreshToken;
    _userId = session.userId;
    _email = session.email;
    await _rebindIfNeeded(session.userId, session.accessToken);
    if (epoch != _epoch || _refreshToken == null) return;
    await _emit(SignedIn(session.userId, session.email));
  }

  /// One rebind at a time. A second caller awaits the same flight.
  ///
  /// [AccountMismatch] drops the session that was just stored.
  /// The local database is unchanged because the hook throws first.
  Future<void> _rebindIfNeeded(String userId, String accessToken) async {
    if (beforeSignedIn == null || _reboundFor == userId) return;
    final existing = _rebindFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final epoch = _epoch;
    final run = _runRebind(userId, accessToken, epoch);
    _rebindFlight = run;
    try {
      await run;
    } finally {
      if (identical(_rebindFlight, run)) _rebindFlight = null;
    }
  }

  Future<void> _runRebind(String userId, String accessToken, int epoch) async {
    try {
      await beforeSignedIn!(userId, accessToken);
    } on AccountMismatch {
      if (epoch == _epoch) {
        _epoch++;
        await _clear(emit: true);
      }
      rethrow;
    }
    if (epoch != _epoch) return;
    _reboundFor = userId;
  }

  Future<void> _clear({required bool emit}) async {
    _accessToken = null;
    _accessExpiresAt = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
    _reboundFor = null;
    try {
      await _store.delete(refreshTokenKey);
    } catch (_) {}
    try {
      await _store.delete(userIdKey);
    } catch (_) {}
    if (emit) await _emit(const SignedOut());
  }

  Future<void> _emitRestored() async {
    final userId = _userId;
    final refresh = _refreshToken;
    if (userId == null || refresh == null || refresh.isEmpty) {
      await _emit(const SignedOut());
      return;
    }
    if (beforeSignedIn == null || _reboundFor == userId) {
      await _emit(SignedIn(userId, _email));
      return;
    }
    // Refresh failed before rebind. Keep the tokens and do not tell
    // the flush worker that a session is ready.
    await _emit(const SignedOut());
  }

  /// Delivers [next] before returning, so a caller that awaits a
  /// session method observes the state change on [stateStream].
  Future<void> _emit(AuthState next) async {
    _state = next;
    if (_states.isClosed) return;
    _states.add(next);
    await Future<void>.value();
  }

  Future<http.Response> _post(String path, Map<String, Object?> body) async {
    try {
      return await _http.post(
        Uri.parse('$_baseUrl$path'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
    } on AuthHttpException {
      rethrow;
    } catch (_) {
      throw const AuthNetworkException('auth transport failed');
    }
  }

  static bool _isRefreshInvalid(http.Response resp) {
    final code = _errorCode(resp.body);
    return code == null || code == 'refresh_invalid';
  }

  static String? _errorCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final error = decoded['error'];
      if (error is! Map) return null;
      final code = error['code'];
      return code is String ? code : null;
    } catch (_) {
      return null;
    }
  }

  static _SessionBody _parseSession(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const AuthHttpException(200, 'session body is not json');
    }
    if (decoded is! Map) {
      throw const AuthHttpException(200, 'session body is not an object');
    }
    final userId = decoded['user_id'];
    final access = decoded['access_token'];
    final refresh = decoded['refresh_token'];
    if (userId is! String ||
        userId.isEmpty ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const AuthHttpException(200, 'session body is incomplete');
    }
    final email = decoded['email'];
    return _SessionBody(
      userId: userId,
      email: email is String ? email : null,
      accessToken: access,
      refreshToken: refresh,
      expiresIn: _expiresIn(decoded['expires_in']),
    );
  }

  static int _expiresIn(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    return 900;
  }

  static String _trimSlash(String baseUrl) {
    if (baseUrl.endsWith('/')) return baseUrl.substring(0, baseUrl.length - 1);
    return baseUrl;
  }
}
