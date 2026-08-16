# tests/photos — pointer

`docs/specs/photo-pipeline.md` §"Test expectations" places the receipt-photo
tests in `tests/photos/`. They live in the Flutter client instead, so
`flutter test` picks them up without a second runner:

| Spec expectation | Implementation |
|------------------|----------------|
| 1. EXIF strip | [`client/test/photos/photo_processing_test.dart`](../../client/test/photos/photo_processing_test.dart) |
| 2. TTL purge | [`client/test/photos/photo_ttl_test.dart`](../../client/test/photos/photo_ttl_test.dart) + [`photo_service_test.dart`](../../client/test/photos/photo_service_test.dart) §"cleanup sweep" |
| 3. Orphan handling | [`client/test/photos/photo_service_test.dart`](../../client/test/photos/photo_service_test.dart) §"cleanup sweep" |
| 4. Export exclusion | [`client/test/photos/no_upload_invariant_test.dart`](../../client/test/photos/no_upload_invariant_test.dart) — guard; ZIP assertions in [`client/test/export/`](../../client/test/export/) (CES-41) |
| 5. Sandbox backup disabled | `android:allowBackup="false"` in [`client/android/app/src/main/AndroidManifest.xml`](../../client/android/app/src/main/AndroidManifest.xml); **not** covered by an automated test (needs a device — see the manual checklist) |

Also here, beyond the spec list:

- Never-in-outbox invariant — [`no_upload_invariant_test.dart`](../../client/test/photos/no_upload_invariant_test.dart)
- Module purity guard — [`module_purity_test.dart`](../../client/test/photos/module_purity_test.dart)
- Log tab attach / preview / delete UI — [`client/test/app/log_page_photos_test.dart`](../../client/test/app/log_page_photos_test.dart)

**Fixtures** are generated in memory by
[`client/test/photos/_fixtures.dart`](../../client/test/photos/_fixtures.dart)
rather than committed as binaries, so each test declares exactly which
sensitive EXIF tags it expects to be removed.

Run them with:

```bash
cd client && flutter test --no-pub test/photos/ test/app/log_page_photos_test.dart
```
