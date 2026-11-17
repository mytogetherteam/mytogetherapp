import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'picked_image.dart';

class VideoCompressHelper {
  /// Compresses a picked video file to 720p H.264 with optimized bitrate.
  /// Reduces 50MB-100MB camera recordings down to ~3MB-6MB.
  /// Falls back to the original file if compression fails or on desktop.
  static Future<PickedImage> compressAndConvert(XFile file) async {
    // Web or unsupported platform fallback
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return PickedImage.fromXFile(file);
    }

    try {
      final originalLength = await file.length();
      final originalMb = originalLength / (1024 * 1024);
      debugPrint('[VideoCompress] Starting compression for ${file.name} (${originalMb.toStringAsFixed(1)} MB)...');

      final mediaInfo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality, // 720p standard for mobile feeds
        deleteOrigin: false,
        includeAudio: true,
      );

      final compressedFile = mediaInfo?.file;
      if (compressedFile != null && await compressedFile.exists()) {
        final compressedBytes = await compressedFile.readAsBytes();
        final compressedMb = compressedBytes.length / (1024 * 1024);
        debugPrint('[VideoCompress] Compression completed: ${compressedMb.toStringAsFixed(1)} MB (Saved ${((1 - compressedMb / (originalMb > 0 ? originalMb : 1)) * 100).toStringAsFixed(0)}%)');

        // Extract poster thumbnail frame so feed doesn't buffer full video to preview
        Uint8List? thumbBytes;
        try {
          final thumbFile = await VideoCompress.getFileThumbnail(
            file.path,
            quality: 75,
          );
          if (await thumbFile.exists()) {
            thumbBytes = await thumbFile.readAsBytes();
          }
        } catch (e) {
          debugPrint('[VideoCompress] Poster thumbnail generation failed: $e');
        }

        final durationSeconds = mediaInfo?.duration != null
            ? (mediaInfo!.duration! > 1000
                ? (mediaInfo.duration! / 1000).round()
                : mediaInfo.duration!.round())
            : null;

        return PickedImage(
          bytes: compressedBytes,
          filename: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          mimeType: 'video/mp4',
          thumbnailBytes: thumbBytes,
          duration: durationSeconds,
        );
      }
    } catch (e) {
      debugPrint('[VideoCompress] Compression error, falling back to original: $e');
    }

    // Fallback to original if compression failed
    return PickedImage.fromXFile(file);
  }

  /// Cleans up temporary compressed video files from cache
  static Future<void> clearCache() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await VideoCompress.deleteAllCache();
      }
    } catch (_) {}
  }
}
