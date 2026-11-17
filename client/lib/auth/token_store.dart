import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key/value store for the refresh token and `user_id`.
///
/// The access token is not written here. It lives in memory.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore-backed store (CES-87).
///
/// `flutter_secure_storage` 9.2.4 keeps the secret key in the Android
/// Keystore (RSA) and the ciphertext in app-private storage. iOS uses
/// the Keychain. Unit tests inject a memory store instead of this one.
class FlutterSecureTokenStore implements TokenStore {
  FlutterSecureTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
