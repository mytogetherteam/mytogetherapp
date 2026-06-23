import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> saveImageBytes(Uint8List bytes, {required String name}) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = name.endsWith('.png') ? name : '$name.png'
    ..click();
  html.Url.revokeObjectUrl(url);
}
