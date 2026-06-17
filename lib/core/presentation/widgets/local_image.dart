import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

export 'local_image_provider_io.dart'
    if (dart.library.html) 'local_image_provider_web.dart';

/// Displays an image that was just picked from the device/gallery in a way that
/// works on every platform, including Flutter web / PWA.
///
/// Uses in-memory bytes so we never rely on `dart:io` filesystem paths, which
/// are unavailable on the web.
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
    return FutureBuilder<List<int>>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: width,
            height: height ?? 120,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.memory(
          Uint8List.fromList(snapshot.data!),
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }
}
