import 'package:flutter/foundation.dart';

class EnvConfig {
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static const String _baseUrlStaging = 'http://localhost:3001';
  static const String _baseUrlProduction = 'https://api.mytogether.org';

  static const String _wsUrlStaging = 'ws://localhost:3001/ws/websocket';
  static const String _wsUrlProduction = 'wss://api.mytogether.org/ws/websocket';

  static String _localizeUrl(String url) {
    if (kIsWeb) return url;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return url
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return url;
  }

  static String get apiBaseUrl {
    final url = appEnv == 'staging' ? _baseUrlStaging : _baseUrlProduction;
    return _localizeUrl(url);
  }

  static String get wsUrl {
    final url = appEnv == 'staging' ? _wsUrlStaging : _wsUrlProduction;
    return _localizeUrl(url);
  }

  static const String apiPrefix = '/api';

  static bool get isStaging => appEnv == 'staging';
  static bool get isProduction => appEnv == 'production';
}
