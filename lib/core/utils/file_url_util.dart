import '../config/env_config.dart';

/// Resolves stored file keys / relative paths to loadable URLs.
/// Mirrors backend `toPublicFileUrl` in file-url.util.ts.
class FileUrlUtil {
  static const String s3PublicBase =
      'https://my-together-moonlight201.s3.ap-southeast-1.amazonaws.com';

  static String resolve(String? value) {
    if (value == null || value.isEmpty) return '';

    if (value.contains('pinterest.com')) return '';

    final str = value.trim();
    if (str.startsWith('http://') || str.startsWith('https://')) return str;
    if (str.startsWith('assets/')) return str;
    if (str.startsWith('data:')) return str;

    final path = str.startsWith('/') ? str.substring(1) : str;

    if (path.startsWith('uploads/')) {
      final base = EnvConfig.apiBaseUrl.endsWith('/')
          ? EnvConfig.apiBaseUrl.substring(0, EnvConfig.apiBaseUrl.length - 1)
          : EnvConfig.apiBaseUrl;
      return '$base/$path';
    }

    return '$s3PublicBase/$path';
  }
}
