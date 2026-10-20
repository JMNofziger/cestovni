/// HTTP client for the M3 outbox and for the CES-45 restore reads.
///
/// Contract: `docs/specs/sync-protocol.md`. Batches are ≤100 mutations.
/// Auth is `Authorization: Bearer`. The bearer is either the
/// compile-time token or whatever [tokenProvider] returns (a JWT, once
/// sign-in exists). This file does not parse the token.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../db/app_database.dart' show OutboxRow;

/// A single mutation result returned by `POST /api/v1/mutations`.
class MutationResult {
  const MutationResult({
    required this.mutationId,
    required this.status,
    this.rowId,
    this.rowVersion,
    this.serverUpdatedAt,
    this.errorCode,
    this.errorMessage,
    this.errorRetriable,
  });

  final String mutationId;

  /// `applied` | `duplicate` | `rejected`. Unknown values pass through
  /// as-is so the caller can log + dead-letter them.
  final String status;
  final String? rowId;
  final int? rowVersion;
  final String? serverUpdatedAt;
  final String? errorCode;
  final String? errorMessage;
  final bool? errorRetriable;

  bool get isAccepted => status == 'applied' || status == 'duplicate';
  bool get isRejected => status == 'rejected';

  factory MutationResult.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>?;
    return MutationResult(
      mutationId: json['mutation_id'] as String,
      status: json['status'] as String,
      rowId: json['row_id'] as String?,
      rowVersion: (json['row_version'] as num?)?.toInt(),
      serverUpdatedAt: json['server_updated_at'] as String?,
      errorCode: error?['code'] as String?,
      errorMessage: error?['message'] as String?,
      errorRetriable: error?['retriable'] as bool?,
    );
  }
}

/// Top-level outcome of a `POST /api/v1/mutations` call. Per-mutation
/// results live in [results]. HTTP-level failures throw [SyncHttpError].
class MutationResponse {
  const MutationResponse({required this.results});
  final List<MutationResult> results;
}

/// One page of `GET /api/v1/changes`.
class ChangesPage {
  const ChangesPage({
    required this.table,
    required this.rows,
    required this.nextSince,
    required this.hasMore,
    required this.limitClamped,
  });

  final String table;
  final List<Map<String, dynamic>> rows;
  final int nextSince;
  final bool hasMore;
  final bool limitClamped;
}

/// One table line from `GET /api/v1/restore/manifest`.
class RestoreTableCount {
  const RestoreTableCount({
    required this.table,
    required this.rowCount,
    required this.maxRowVersion,
  });

  final String table;
  final int rowCount;
  final int maxRowVersion;
}

class RestoreManifest {
  const RestoreManifest({required this.tables});
  final List<RestoreTableCount> tables;
}

/// Thrown for transport / 4xx / 5xx failures from the sync endpoint.
/// `retriable` follows `sync-protocol.md` §HTTP status map.
class SyncHttpError implements Exception {
  const SyncHttpError({
    required this.statusCode,
    required this.message,
    required this.retriable,
    this.retryAfterSeconds,
  });

  final int statusCode;
  final String message;
  final bool retriable;

  /// Integer `Retry-After` when the server sent one. HTTP-date values
  /// are ignored; the CES-43 API sends seconds.
  final int? retryAfterSeconds;

  @override
  String toString() =>
      'SyncHttpError($statusCode, retriable=$retriable): $message';
}

class SyncClient {
  SyncClient({
    required this.baseUrl,
    required this.bearerToken,
    this.tokenProvider,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// e.g. `http://127.0.0.1:8080` or the dev stub on `:8787`.
  final String baseUrl;

  /// Fallback bearer when [tokenProvider] returns null or empty.
  final String bearerToken;

  /// Runtime JWT (or any bearer). Checked on every request so a refresh
  /// does not require a new client.
  final String? Function()? tokenProvider;

  final http.Client _http;

  String get _authorization {
    final runtime = tokenProvider?.call();
    if (runtime != null && runtime.isNotEmpty) return runtime;
    return bearerToken;
  }

  Future<MutationResponse> postMutations(List<OutboxRow> batch) async {
    if (batch.isEmpty) {
      return const MutationResponse(results: []);
    }
    final body = jsonEncode({
      'mutations': batch.map(_serialize).toList(growable: false),
    });
    final resp = await _send(
      'POST',
      Uri.parse('$baseUrl/api/v1/mutations'),
      body: body,
    );
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = (json['results'] as List).cast<Map<String, dynamic>>();
    return MutationResponse(
      results: raw.map(MutationResult.fromJson).toList(growable: false),
    );
  }

  /// Catch-up page. [limit] is omitted when null so the server default
  /// (200) applies. The server clamps above 500 and sets
  /// `X-Limit-Clamped`.
  Future<ChangesPage> getChanges({
    required String table,
    int since = 0,
    int? limit,
  }) async {
    final params = <String, String>{
      'table': table,
      'since': '$since',
      if (limit != null) 'limit': '$limit',
    };
    final uri = Uri.parse('$baseUrl/api/v1/changes').replace(
      queryParameters: params,
    );
    final resp = await _send('GET', uri);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = json['rows'] as List? ?? const [];
    return ChangesPage(
      table: json['table'] as String? ?? table,
      rows: [
        for (final item in raw) Map<String, dynamic>.from(item as Map),
      ],
      nextSince: (json['next_since'] as num?)?.toInt() ?? since,
      hasMore: json['has_more'] == true,
      limitClamped: resp.headers['x-limit-clamped'] == 'true',
    );
  }

  /// Per-table counts for the restore progress UI (CES-45).
  Future<RestoreManifest> getRestoreManifest() async {
    final resp = await _send(
      'GET',
      Uri.parse('$baseUrl/api/v1/restore/manifest'),
    );
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = json['tables'] as List? ?? const [];
    return RestoreManifest(
      tables: [
        for (final item in raw)
          _restoreTable(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  void close() => _http.close();

  static RestoreTableCount _restoreTable(Map<String, dynamic> item) {
    return RestoreTableCount(
      table: item['table'] as String,
      rowCount: (item['row_count'] as num).toInt(),
      maxRowVersion: (item['max_row_version'] as num).toInt(),
    );
  }

  Future<http.Response> _send(String method, Uri uri, {String? body}) async {
    final headers = <String, String>{
      'Authorization': 'Bearer $_authorization',
      if (body != null) 'Content-Type': 'application/json',
    };
    http.Response resp;
    try {
      if (method == 'POST') {
        resp = await _http.post(uri, headers: headers, body: body);
      } else {
        resp = await _http.get(uri, headers: headers);
      }
    } catch (e) {
      throw SyncHttpError(
        statusCode: 0,
        message: 'transport error: $e',
        retriable: true,
      );
    }
    if (resp.statusCode == 200) return resp;
    throw SyncHttpError(
      statusCode: resp.statusCode,
      message: resp.body,
      retriable: _isStatusRetriable(resp.statusCode),
      retryAfterSeconds: _retryAfterSeconds(resp.headers['retry-after']),
    );
  }

  Map<String, dynamic> _serialize(OutboxRow row) {
    return <String, dynamic>{
      'mutation_id': row.mutationId,
      'table': row.table_,
      'op': row.op,
      'row_id': row.rowId,
      if (row.payloadJson != null)
        'payload': jsonDecode(row.payloadJson!) as Map<String, dynamic>,
    };
  }

  static int? _retryAfterSeconds(String? header) {
    if (header == null) return null;
    final parsed = int.tryParse(header.trim());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  static bool _isStatusRetriable(int code) {
    // sync-protocol.md §HTTP status map.
    if (code == 401 || code == 429) return true;
    if (code >= 500 && code < 600) return true;
    return false;
  }
}
