/// Export exclusion guard for receipt photos.
///
/// Spec: `docs/specs/export-v1.md` + `docs/specs/photo-pipeline.md`
/// §"Export interaction" — the ZIP export never contains photo bytes and
/// `manifest.json` carries `photos_in_export: false` as a hard-coded
/// assertion.
///
/// The ZIP export itself is CES-41 and is deliberately not implemented here.
/// This file exists so that when it lands there is exactly one place to call
/// rather than a fresh judgement call about which paths are safe to bundle.
///
/// Pure module: no Flutter, no Drift, no file IO.
library;

/// Sandbox subdirectory holding receipt JPEGs.
const String photosDirectoryName = 'photos';

/// Value the export manifest must always carry.
const bool photosInExport = false;

/// Whether [path] points inside the photo sandbox (and so must never be
/// bundled). Accepts POSIX and Windows separators, absolute or relative.
bool isPhotoSandboxPath(String path) {
  final segments = path.split(RegExp(r'[/\\]'));
  return segments.contains(photosDirectoryName);
}

/// [paths] with every photo-sandbox entry removed. Export builds the ZIP
/// file list through this function; anything it drops is by design.
List<String> excludePhotoPaths(Iterable<String> paths) =>
    paths.where((path) => !isPhotoSandboxPath(path)).toList();
