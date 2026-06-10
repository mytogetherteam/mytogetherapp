import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

/// Builds a Dio [MultipartFile] from an [XFile] in a way that works on every
/// platform, including Flutter web / PWA.
///
/// On the web there is no real filesystem path, so `MultipartFile.fromFile`
/// (which relies on `dart:io`) throws at runtime. Reading the picked image into
/// memory with [XFile.readAsBytes] and using `MultipartFile.fromBytes` keeps the
/// same upload working across mobile and web.
///
/// When [filenamePrefix] is provided the uploaded file is named
/// `<prefix>.<ext>` where the extension is inferred from the original file;
/// otherwise the picker-provided name is reused.
Future<MultipartFile> multipartFromXFile(
  XFile file, {
  String? filenamePrefix,
}) async {
  final bytes = await file.readAsBytes();
  final originalName = file.name;
  final ext = originalName.contains('.')
      ? originalName.split('.').last.toLowerCase()
      : 'jpg';
  final mimeType = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/jpeg',
  };
  final filename = filenamePrefix != null ? '$filenamePrefix.$ext' : originalName;
  return MultipartFile.fromBytes(
    bytes,
    filename: filename,
    contentType: DioMediaType.parse(mimeType),
  );
}
