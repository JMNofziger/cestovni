/// Minimal HTTP client for the M3 outbox flush worker (CES-44 gate
/// slice). Targets the dev sync stub at `server/dev-sync-stub/`;
/// replaced by the proper M3 client once CES-43 lands.
///
/// Contract: `docs/specs/sync-protocol.md` §POST /mutations + §HTTP
/// status map. We send batches of ≤100 mutations and return per-result
/// outcomes (`applied` | `duplicate` | `rejected`).
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

/// Thrown for transport / 4xx / 5xx failures from the sync endpoint.
/// `retriable` follows `sync-protocol.md` §HTTP status map.
class SyncHttpError implements Exception {
  const SyncHttpError({
    required this.statusCode,
    required this.message,
    required this.retriable,
  });

  final int statusCode;
  final String message;
  final bool retriable;

  @override
  String toString() => 'SyncHttpError($statusCode, retriable=$retriable): $message';
}

class SyncClient {
  SyncClient({
    required this.baseUrl,
    required this.bearerToken,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// e.g. `http://127.0.0.1:8787`.
  final String baseUrl;
  final String bearerToken;
  final http.Client _http;

  Future<MutationResponse> postMutations(List<OutboxRow> batch) async {
    if (batch.isEmpty) {
      return const MutationResponse(results: []);
    }
    final body = jsonEncode({
      'mutations': batch.map(_serialize).toList(growable: false),
    });

    http.Response resp;
    try {
      resp = await _http.post(
        Uri.parse('$baseUrl/api/v1/mutations'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );
    } catch (e) {
      throw SyncHttpError(
        statusCode: 0,
        message: 'transport error: $e',
        retriable: true,
      );
    }

    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = (json['results'] as List).cast<Map<String, dynamic>>();
      return MutationResponse(
        results: raw.map(MutationResult.fromJson).toList(growable: false),
      );
    }

    throw SyncHttpError(
      statusCode: resp.statusCode,
      message: resp.body,
      retriable: _isStatusRetriable(resp.statusCode),
    );
  }

  void close() => _http.close();

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

  static bool _isStatusRetriable(int code) {
    // sync-protocol.md §HTTP status map.
    if (code == 401 || code == 429) return true;
    if (code >= 500 && code < 600) return true;
    return false;
  }
}
