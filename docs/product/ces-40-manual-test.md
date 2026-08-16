# Manual test guide — CES-40 receipt photo pipeline

Automated coverage is already green (`cd client && flutter analyze && flutter test --no-pub`
— 245 tests, 1 gated E2E skipped; 46 of those tests are new in CES-40). This
checklist covers only what a human on a real device can confirm: a real camera,
a real photo library, real OS permission prompts, and the OS backup setting.

**You need:** a physical Android phone with a camera, USB debugging on, and the
Android SDK on your machine. The Cloud VM has neither an Android SDK nor a
camera, so none of this runs in CI.

---

## Setup (once, ~5 min)

```bash
cd client
flutter devices                 # confirm your phone is listed
flutter run                     # debug build onto the phone
```

Then in the app: tap the gear → add a vehicle → confirm it shows in the header chip.

Handy shell aliases for the checks below (debug builds only — `run-as` needs a
debuggable app):

```bash
PKG=com.personalinterests.cestovni.cestovni
photos() { adb shell run-as $PKG ls -l app_flutter/photos/ 2>/dev/null; }
pull_photo() { adb exec-out run-as $PKG cat "app_flutter/photos/$1" > "/tmp/$1"; }
```

---

## Checklist

### 1. Attach from the camera

1. Log tab → find the **RECEIPT PHOTO (OPT.)** card between the form and `ADVANCED`.
2. Tap **CAMERA** → accept the permission prompt → photograph any receipt or
   printed page.

- [ ] Counter reads `1 / 5` and a thumbnail appears.
- [ ] `photos` shows exactly one `<uuid>.jpg`.
- [ ] File size is roughly 100–250 KB (not the multi-MB camera original).

### 2. Attach from the library

1. Tap **LIBRARY** → accept the prompt → pick any photo, ideally one with
   location data (taken outdoors with location services on).

- [ ] Counter reads `2 / 5`, two thumbnails.

### 3. EXIF is really gone — the core privacy check

```bash
photos                          # copy one filename
pull_photo <uuid>.jpg
exiftool /tmp/<uuid>.jpg        # or: exiv2 -pa /tmp/<uuid>.jpg
```

- [ ] **No** `GPS*` tags of any kind.
- [ ] **No** `Make`, `Model`, `Software`, `Artist`, `Serial Number`, `Owner Name`,
      or `Maker Note`.
- [ ] Long edge is 1600 px or less; the image is upright (not sideways), which
      confirms the orientation tag was baked into the pixels before being dropped.

> Compare against the same photo pulled straight off the phone's camera roll —
> that one *should* still show GPS. If both are clean, your source photo had no
> GPS and the test proved nothing; retake it outdoors with location on.

### 4. Five-photo cap

Attach until the counter reads `5 / 5`.

- [ ] **CAMERA** and **LIBRARY** are greyed out and unresponsive.
- [ ] Copy reads "Limit of 5 photos reached. Delete one to add another."

### 5. Preview and delete

1. Tap any thumbnail.

- [ ] Full-size preview opens with **CLOSE** and **DELETE PHOTO**.
- [ ] **CLOSE** leaves the count unchanged.
- [ ] **DELETE PHOTO** dismisses the dialog, the thumbnail disappears, the
      counter drops, and the attach buttons re-enable.
- [ ] `photos` shows one fewer file.

### 6. Permission denial never blocks a fill-up

1. Android Settings → Apps → Cestovni → Permissions → **deny** Camera.
2. Back in the app, Log tab → tap **CAMERA** → dismiss the prompt / it fails.

- [ ] The **CAMERA** and **LIBRARY** buttons are replaced by "Camera and photo
      access are off. You can still save the fill-up."
- [ ] Fill in odometer / volume / total and tap **SAVE ENTRY** → "Fill-up saved".
- [ ] The entry shows up on History.

Re-grant the permission afterwards and confirm the buttons come back after a
restart.

### 7. Photos never reach the outbox

1. Re-grant permissions, attach 1–2 photos to a fresh draft, then **SAVE ENTRY**.
2. Gear → **Debug**.

- [ ] `Outbox pending` increased by exactly **1** (the fill-up), not by the
      number of photos.
- [ ] `Run PRAGMA integrity_check` reports `ok`.

Optional deeper check:

```bash
adb exec-out run-as $PKG cat app_flutter/cestovni.sqlite > /tmp/cestovni.sqlite
sqlite3 /tmp/cestovni.sqlite 'SELECT "table", length(payload_json) FROM outbox;'
sqlite3 /tmp/cestovni.sqlite 'SELECT id, byte_size, captured_at, ttl_expires_at FROM photo_refs;'
```

- [ ] No outbox row has `table = 'photo_refs'`.
- [ ] No payload is large enough to contain an image (each is a few hundred bytes).
- [ ] For the photos on the entry you just saved, `ttl_expires_at` is about
      **7 days** from now, not 30 — completing the entry shortened the window.
- [ ] For photos still on an open draft, `ttl_expires_at` is about **30 days**
      from the capture time.

### 8. Draft photos survive a restart

1. Attach a photo, do **not** save, force-stop the app, reopen it.

- [ ] The Log tab restores the draft with its thumbnail intact.

### 9. OS backup is disabled

```bash
adb shell dumpsys package $PKG | grep -i allowBackup
```

- [ ] Reports `false` (or no `ALLOW_BACKUP` flag).

### 10. Photo purge on device (spot check)

The 30-day TTL is impractical to wait out, but the sweep itself is easy to
observe:

1. Note a photo id from `photo_refs`.
2. Delete its file behind the app's back:
   `adb shell run-as $PKG rm app_flutter/photos/<uuid>.jpg`
3. Force-stop, wait an hour (the sweep is throttled to once per hour), reopen
   the Log tab.

- [ ] The orphaned row is gone from `photo_refs` and the app did not crash.
- [ ] If you reopen within the hour instead, nothing is swept — that is the
      throttle working, not a bug.

---

## Known gaps to confirm, not fix

These are deliberate and already recorded in the PR and on
[CES-40](https://linear.app/personal-interests-llc/issue/CES-40):

- **iOS backup exclusion is not implemented.** `Info.plist` carries the camera
  and library usage strings, but nothing sets `NSURLIsExcludedFromBackupKey` on
  `photos/`. iPhone is served by the PWA-lite in Stage 1 (ADR 005), so no iOS
  build ships this feature yet.
- **No "had a receipt" icon on completed fill-ups.** The spec lists it as a UX
  nicety; it needs a column on `fill_ups`, which means a schema migration and a
  product decision.
- **No photo telemetry.** `photo_capture` / `had_photo` are allowlisted but
  deliberately unwired until M4 (CES-46).
- **Photos are lost when you switch phones.** Expected v1 behaviour — they are
  local-only by design.
