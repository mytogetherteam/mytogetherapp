import 'package:dio/dio.dart';

import '../network/api_client.dart';

/// One admin push that sets this app to Thai. [at] changes each time the switch is turned on.
class LanguagePush {
  const LanguagePush({required this.enabled, required this.at});

  final bool enabled;
  final String? at;
}

class LanguagePolicyClient {
  static Future<LanguagePush?> fetch(String app) async {
    try {
      final response = await ApiClient().dio.get(
        '/api/app/language-policy',
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          extra: const {'isRetry': true},
        ),
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map || !data.containsKey(app)) return null;
      final at = data['${app}ForcedAt'];
      return LanguagePush(
        enabled: data[app] == true,
        at: at is String ? at : null,
      );
    } catch (_) {}
    return null;
  }
}
