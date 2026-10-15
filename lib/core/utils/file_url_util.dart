import '../config/env_config.dart';

/// Resolves stored file keys / relative paths to loadable URLs.
/// Mirrors backend `toPublicFileUrl` in file-url.util.ts.
class FileUrlUtil {
  static const String _defaultS3Base =
      'https://my-together-moonlight201.s3.ap-southeast-1.amazonaws.com';

  static String get s3PublicBase {
    if (EnvConfig.cdnUrl.isNotEmpty) {
      return EnvConfig.cdnUrl.endsWith('/')
          ? EnvConfig.cdnUrl.substring(0, EnvConfig.cdnUrl.length - 1)
          : EnvConfig.cdnUrl;
    }
    return _defaultS3Base;
  }

  static String resolve(dynamic value) {
    if (value == null) return '';
    final str = value.toString().trim();
    if (str.isEmpty) return '';

    if (str.contains('pinterest.com')) return '';

    // Automatically rewrite direct S3 URLs to CDN / centralized base
    const s3Pattern = 'my-together-moonlight201.s3';
    if (str.contains(s3Pattern)) {
      try {
        final uri = Uri.parse(str);
        final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        return '$s3PublicBase/$path';
      } catch (_) {}
    }

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
