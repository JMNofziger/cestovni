/// TTL arithmetic for receipt photos.
///
/// Spec: `docs/specs/photo-pipeline.md` §Lifecycle — a photo lives until the
/// **shorter** of 30 days from capture or 7 days after the linked fill-up
/// completes.
///
/// Pure module: no Flutter, no Drift, no file IO.
library;

/// Photos expire 30 days after capture even if the draft is never finished.
const Duration photoCaptureTtl = Duration(days: 30);

/// Once the draft is promoted to a fill-up the photo has served its purpose,
/// so the window shrinks to 7 days.
const Duration photoPostCompletionTtl = Duration(days: 7);

/// TTL stamped on the row at attach time.
DateTime captureTtlExpiry(DateTime capturedAt) =>
    capturedAt.toUtc().add(photoCaptureTtl);

/// TTL after the linked draft completes. Completion only ever shortens the
/// window — a fill-up entered 29 days late must not extend a photo's life.
DateTime completionTtlExpiry({
  required DateTime completedAt,
  required DateTime currentExpiry,
}) {
  final shortened = completedAt.toUtc().add(photoPostCompletionTtl);
  final current = currentExpiry.toUtc();
  return shortened.isBefore(current) ? shortened : current;
}

/// Whether a photo is due for purging. Boundary is inclusive so a row whose
/// TTL lands exactly on [now] is swept in this pass rather than the next.
bool isPhotoExpired({required DateTime ttlExpiresAt, required DateTime now}) =>
    !ttlExpiresAt.toUtc().isAfter(now.toUtc());
