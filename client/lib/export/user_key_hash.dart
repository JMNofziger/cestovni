/// Stand-in `user_key_hash` until CES-46 wires telemetry.
///
/// Locked decision 6: first 8 hex chars of SHA-256 over `settings.id`.
/// Documented in `README_export.txt` so a later telemetry key does not
/// silently change the filename contract without a spec bump.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

String userKeyHashFromSettingsId(String settingsId) {
  final digest = sha256.convert(utf8.encode(settingsId));
  return digest.toString().substring(0, 8);
}

/// SHA-256 hex over the sorted pending `mutation_id`s, one per line.
/// Returns `null` when [sortedIds] is empty (spec: hash is null at count 0).
String? outboxPendingHash(Iterable<String> sortedIds) {
  final list = sortedIds.toList()..sort();
  if (list.isEmpty) return null;
  return sha256.convert(utf8.encode(list.join('\n'))).toString();
}
