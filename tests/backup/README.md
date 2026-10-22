# tests/backup — pointer

`docs/specs/sync-protocol.md` §Restore flow and §Dead-letter handling
place the backup integration tests in `tests/backup/`. They live in the
Flutter client so `flutter test` picks them up without a second runner.
The "server" in these tests is an in-memory `GET /changes` fixture, the
same shape the CES-43 API returns.

| Expectation | Implementation |
| --- | --- |
| Restore convergence (local DB matches server rows) | [`client/test/sync/restore_service_test.dart`](../../client/test/sync/restore_service_test.dart) |
| Partial restore resumes from the last committed cursor | same file |
| Replayed page does not duplicate `(id, row_version)` | same file |
| Local unsynced rows stay; a matching id takes the server row | same file |
| Cancel leaves the device usable | same file |
| Dead-letter retry and discard | [`client/test/sync/dead_letter_test.dart`](../../client/test/sync/dead_letter_test.dart) |
| Progress UI and dead-letter actions | [`client/test/app/restore_progress_view_test.dart`](../../client/test/app/restore_progress_view_test.dart), [`client/test/app/backup_section_test.dart`](../../client/test/app/backup_section_test.dart) |

There is no 10k-row device timing gate here. That stays with CES-68.

```bash
cd client && flutter test --no-pub \
  test/sync/restore_service_test.dart \
  test/sync/dead_letter_test.dart \
  test/app/restore_progress_view_test.dart \
  test/app/backup_section_test.dart
```
