import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

/// Lightweight wrapper around `image_cropper` so every upload flow can offer a
/// consistent, mobile-friendly crop step without each screen re-implementing
/// the UI configuration.
class ImageCropHelper {
  ImageCropHelper._();

  /// Opens a native crop screen for [file].
  ///
  /// Returns the cropped file, or `null` if the user backs out of the crop
  /// screen (treat as a cancelled selection). On web — where the native
  /// cropper isn't wired up — or if cropping fails, the original [file] is
  /// returned so the upload flow is never blocked.
  ///
  /// Set [square] to lock a 1:1 ratio (nice for avatars); otherwise the user
  /// can freely frame the image.
  static Future<XFile?> crop(XFile file, {bool square = false}) async {
    if (kIsWeb) return file;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio:
            square ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: AppColors.primary,
            lockAspectRatio: square,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: square,
            resetAspectRatioEnabled: !square,
          ),
        ],
      );
      return cropped == null ? null : XFile(cropped.path);
    } catch (e) {
      debugPrint('ImageCropHelper.crop error: $e');
      return file;
    }
  }
}
