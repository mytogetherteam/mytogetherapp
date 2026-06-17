import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser file download for the given bytes (Flutter web / PWA).
Future<void> downloadBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
