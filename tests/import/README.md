# tests/import — pointer

`docs/specs/export-import.md` § Test expectations. Cases live in the
Flutter client so `flutter test` picks them up without a second runner:

| Spec expectation | Implementation |
|------------------|----------------|
| 1 Golden round-trip | [`client/test/import/round_trip_test.dart`](../../client/test/import/round_trip_test.dart) |
| 2 Idempotency | `round_trip_test.dart` |
| 3 Header mutation | [`client/test/import/rejects_test.dart`](../../client/test/import/rejects_test.dart) |
| 4 Photo fail-closed | `rejects_test.dart` |
| 5 Derived columns ignored | `round_trip_test.dart` |
| 6 Cadence meters verbatim | `round_trip_test.dart` |
| 7 Value validation + duplicate id | `rejects_test.dart` |
| 8 Atomicity | [`client/test/import/replace_test.dart`](../../client/test/import/replace_test.dart) |
| 9 Never-synced state | `round_trip_test.dart` |
| 10 FK orphan | `rejects_test.dart` |
| 11 Module purity | [`client/test/import/module_purity_test.dart`](../../client/test/import/module_purity_test.dart) |
| 12 Streaming (1 000 rows; device timing is CES-68) | [`client/test/import/streaming_test.dart`](../../client/test/import/streaming_test.dart) |
| 13 Replace clears prior history | `replace_test.dart` |
| 14 `settings` in place | `replace_test.dart` |
| 15 Outbox cleared | `replace_test.dart` |
| 16 Drafts / photos reconcile | `replace_test.dart` |
| 17 Confirmation gate | `replace_test.dart` |
| Header constants == export | [`client/test/import/headers_drift_test.dart`](../../client/test/import/headers_drift_test.dart) |

**Not in CI (per `export-v1.md` § A4):** 10 000-row device timing. That pass moves to [CES-68](https://linear.app/personal-interests-llc/issue/CES-68).

**Not in this folder:** ZIP export ([CES-41](https://linear.app/personal-interests-llc/issue/CES-41)) — see [`../export/README.md`](../export/README.md).

Run them with:

```bash
cd client && flutter test --no-pub test/import/ test/app/settings_page_test.dart
```
