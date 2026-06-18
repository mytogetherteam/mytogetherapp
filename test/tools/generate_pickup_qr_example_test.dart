import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:qr/qr.dart';

/// Generates `assets/examples/pickup_qr_example.png` using the same settings
/// as [PickupOrderQrCard]. Run:
/// `flutter test test/tools/generate_pickup_qr_example_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export branded pickup QR example', () async {
    const payload = '366';
    final qrCode = QrCode.fromData(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    final qrImage = QrImage(qrCode);

    const decoration = PrettyQrDecoration(
      shape: PrettyQrSmoothSymbol(
        color: Colors.black,
        roundFactor: 0.5,
      ),
      background: Colors.white,
      image: PrettyQrDecorationImage(
        image: AssetImage('assets/images/app_icon_small.png'),
        position: PrettyQrDecorationImagePosition.embedded,
      ),
    );

    final byteData = await qrImage.toImageAsBytes(
      size: 512,
      decoration: decoration,
      configuration: ImageConfiguration(
        bundle: rootBundle,
        devicePixelRatio: 1.0,
      ),
    );

    expect(byteData, isNotNull);

    final out = File('assets/examples/pickup_qr_example.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(byteData!.buffer.asUint8List());
  });
}
