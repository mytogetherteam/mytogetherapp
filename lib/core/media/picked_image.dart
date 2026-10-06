import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

/// Cross-platform image picked from the gallery or camera.
/// Uses in-memory bytes so upload and preview work on Web, Android, and iOS.
class PickedImage {
  PickedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;

  double get sizeInMb => bytes.length / (1024 * 1024);

  static Future<PickedImage> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.trim().isNotEmpty
        ? file.name
        : 'media_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return PickedImage(
      bytes: bytes,
      filename: name,
      mimeType: mimeTypeForExtension(ext, file.mimeType),
    );
  }

  bool get isVideo => mimeType.startsWith('video/');

  static String mimeTypeForExtension(String ext, String? fallback) {
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'webm' => 'video/webm',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => (fallback != null && fallback.isNotEmpty) ? fallback : 'image/jpeg',
    };
  }

  MultipartFile toMultipartFile({String? filenameOverride}) {
    return MultipartFile.fromBytes(
      bytes,
      filename: filenameOverride ?? filename,
      contentType: DioMediaType.parse(mimeType),
    );
  }

  String get extension =>
      filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
}
