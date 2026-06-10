import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Displays an image that was just picked from the device/gallery in a way that
/// works on every platform, including Flutter web / PWA.
///
/// On mobile/desktop the picked [XFile] has a real filesystem path, so we use
/// `Image.file`. On the web there is no filesystem path — `dart:io` `File`
/// throws at runtime — so we render the in-memory blob URL via `Image.network`.
class LocalImage extends StatelessWidget {
  const LocalImage({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final XFile file;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(file.path, width: width, height: height, fit: fit);
    }
    return Image.file(File(file.path), width: width, height: height, fit: fit);
  }
}

/// Cross-platform [ImageProvider] for a freshly picked [XFile]. Use this where
/// an `ImageProvider` is required (e.g. `CircleAvatar.backgroundImage`).
ImageProvider localImageProvider(XFile file) {
  if (kIsWeb) {
    return NetworkImage(file.path);
  }
  return FileImage(File(file.path));
}
