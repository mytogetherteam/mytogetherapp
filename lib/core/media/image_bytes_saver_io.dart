import 'dart:typed_data';

import 'package:gal/gal.dart';

Future<void> saveImageBytes(Uint8List bytes, {required String name}) async {
  final hasAccess = await Gal.hasAccess(toAlbum: true);
  if (!hasAccess) {
    final granted = await Gal.requestAccess(toAlbum: true);
    if (!granted) {
      throw Exception('Permission denied');
    }
  }
  await Gal.putImageBytes(bytes, album: 'MyTogether', name: name);
}
