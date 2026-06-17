import 'dart:typed_data';

/// No-op on platforms without browser download APIs.
Future<void> downloadBytes(Uint8List bytes, String filename) async {}
