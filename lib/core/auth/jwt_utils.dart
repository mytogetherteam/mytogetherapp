import 'dart:convert';

class JwtUtils {
  /// Decodes a JWT token payload without validation.
  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payload = _decodeBase64(parts[1]);
      if (payload == null) return null;
      
      return json.decode(payload) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Checks if the token is expired.
  /// [offsetSeconds] can be used to check if the token will expire soon.
  static bool isExpired(String token, {int offsetSeconds = 0}) {
    final payload = decode(token);
    if (payload == null || !payload.containsKey('exp')) {
      return true; // Assume expired if invalid
    }

    final int exp = payload['exp'] as int;
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    return exp < (now + offsetSeconds);
  }

  static String? _decodeBase64(String str) {
    var output = str.replaceAll('-', '+').replaceAll('_', '/');

    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        return null;
    }

    return utf8.decode(base64Url.decode(output));
  }
}
