# tests/export — pointer

`docs/specs/export-v1.md` § Test expectations places export tests in
`tests/export/`. They live in the Flutter client so `flutter test` picks
them up without a second runner:

| Spec expectation | Implementation |
|------------------|----------------|
| Golden ZIP + A1 headers | [`client/test/export/golden_zip_test.dart`](../../client/test/export/golden_zip_test.dart) + [`headers_test.dart`](../../client/test/export/headers_test.dart) |
| CSV rules (BOM, CRLF, quoting, nulls, bools) | [`client/test/export/csv_test.dart`](../../client/test/export/csv_test.dart) |
| Atomicity (failed write leaves no file) | [`client/test/export/atomicity_test.dart`](../../client/test/export/atomicity_test.dart) |
| Photos excluded | [`client/test/export/exclusions_test.dart`](../../client/test/export/exclusions_test.dart) + [`assembler_test.dart`](../../client/test/export/assembler_test.dart) + CES-40 [`no_upload_invariant_test.dart`](../../client/test/photos/no_upload_invariant_test.dart) |
| Outbox pending count + hash | [`client/test/export/outbox_test.dart`](../../client/test/export/outbox_test.dart) |
| Streaming (not a 10k device timing gate) | [`client/test/export/assembler_test.dart`](../../client/test/export/assembler_test.dart) — `CountingZipSink` over a lazy 1 000-row iterable |
| Module purity | [`client/test/export/module_purity_test.dart`](../../client/test/export/module_purity_test.dart) |

**Not in CI (per `export-v1.md` § A4):** 10 000-row / 30 s / 10 MB device timing. That pass moves to [CES-68](https://linear.app/personal-interests-llc/issue/CES-68).

**Not in this folder:** ZIP import ([CES-70](https://linear.app/personal-interests-llc/issue/CES-70)).

Run them with:

```bash
cd client && flutter test --no-pub test/export/ test/app/settings_page_test.dart
```
