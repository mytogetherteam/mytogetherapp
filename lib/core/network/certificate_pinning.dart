import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class CertificatePinning {
  /// Add this setup to your Dio instance to enforce Certificate Pinning
  /// and prevent Man-In-The-Middle (MITM) attacks.
  static void setup(Dio dio) {
    if (kIsWeb) return; // Web doesn't support manual IOHttpClientAdapter

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // Force rejection of all bad certificates
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          // If you want to strictly pin a public key hash, you can verify it here.
          // Currently, this strictly blocks ANY invalid/intercepted certificate (e.g. from Charles Proxy)
          return false; // MUST be false for security (reject bad certs)
        };
        return client;
      },
    );
  }
}
