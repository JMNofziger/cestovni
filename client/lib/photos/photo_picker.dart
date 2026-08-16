/// Camera / photo-library acquisition for receipt photos.
///
/// Spec: `docs/specs/photo-pipeline.md` §"Capture pipeline" step 1 +
/// §"UX rules" (permission denial must never gate a fill-up).
///
/// The abstraction exists so widget tests can hand the Log page bytes
/// directly: the CI VM has no camera, no photo library, and no Android SDK.
library;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// The user (or the OS) refused access. The Log form stays fully usable —
/// callers hide the attach affordance and carry on.
class PhotoPermissionDeniedException implements Exception {
  const PhotoPermissionDeniedException(this.source);

  final PhotoSource source;

  @override
  String toString() =>
      'PhotoPermissionDeniedException: access to $source was denied';
}

abstract class PhotoPicker {
  /// Raw bytes of the chosen image, or null when the user backed out.
  ///
  /// Throws [PhotoPermissionDeniedException] when access was refused.
  Future<Uint8List?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Platform error codes image_picker reports for a refused prompt.
  static const _deniedCodes = {'camera_access_denied', 'photo_access_denied'};

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    try {
      // Full-resolution bytes on purpose: letting the platform downscale
      // would re-encode the image outside our pipeline, which is the one
      // place allowed to decide what metadata survives.
      final picked = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (picked == null) return null;
      return await picked.readAsBytes();
    } on PlatformException catch (error) {
      if (_deniedCodes.contains(error.code)) {
        throw PhotoPermissionDeniedException(source);
      }
      rethrow;
    }
  }
}
