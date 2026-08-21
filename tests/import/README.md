# tests/import — pointer

`docs/specs/export-import.md` § Test expectations places import tests
in `tests/import/` (or a pointer from here). They will live in the
Flutter client so `flutter test` picks them up without a second runner:

| Spec expectation | Implementation |
|------------------|----------------|
| Golden round-trip | **Not written** — expected `client/test/import/` |
| Idempotency, replace, settings in-place, outbox, drafts | **Not written** |
| Header / photo / duplicate-id / FK / value rejects | **Not written** |
| Never-synced state, atomicity, confirmation gate | **Not written** |
| Module purity + streaming | **Not written** |
| Header constants == export | **Not written** — must import `client/lib/export/headers.dart`, never copy |

**Code is implemented** in `client/lib/import/` + Settings → **Import data**
(`client/lib/app/pages/import_data_section.dart`). The 17 cases are the
remaining CES-70 work before this goes 🟩. Do not mark [CES-70](https://linear.app/personal-interests-llc/issue/CES-70) Done, and do not unblock [CES-71](https://linear.app/personal-interests-llc/issue/CES-71), until those tests exist and the code is on `main`.

**Not in this folder:** ZIP export ([CES-41](https://linear.app/personal-interests-llc/issue/CES-41)) — see [`../export/README.md`](../export/README.md).

When tests land, run:

```bash
cd client && flutter test --no-pub test/import/ test/app/settings_page_test.dart
```
