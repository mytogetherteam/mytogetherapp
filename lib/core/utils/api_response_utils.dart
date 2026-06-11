/// Helpers for parsing the NestJS `{ success, data, meta }` envelopes and
/// Spring-style paginated bodies used across myshop_demo_api.
class ApiResponseUtils {
  ApiResponseUtils._();

  static List<T> parseDataList<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = unwrapData(body);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }
    return const [];
  }

  static T? parseDataObject<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = unwrapData(body);
    if (raw is Map<String, dynamic>) {
      return fromJson(raw);
    }
    return null;
  }

  static dynamic unwrapData(dynamic body) {
    if (body is Map && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  /// News / item-post feeds return a `{ content, totalElements, totalPages }`
  /// page. The backend `TransformInterceptor` wraps these plain payloads in a
  /// `{ success, data: { content, ... } }` envelope, while some raw responses
  /// still expose `content` at the top level. Support both by drilling into
  /// `data` whenever it looks like the page object.
  static dynamic _pageBody(dynamic body) {
    if (body is Map) {
      final data = body['data'];
      if (data is Map &&
          (data['content'] != null ||
              data['totalElements'] != null ||
              data['totalPages'] != null)) {
        return data;
      }
    }
    return body;
  }

  static List<T> parseContentPage<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final page = _pageBody(body);
    if (page is Map && page['content'] is List) {
      return (page['content'] as List)
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }
    return const [];
  }

  static int parseTotalElements(dynamic body) {
    final page = _pageBody(body);
    if (page is Map && page['totalElements'] != null) {
      return int.tryParse(page['totalElements'].toString()) ?? 0;
    }
    if (body is Map && body['meta'] is Map) {
      final total = (body['meta'] as Map)['total'];
      return int.tryParse(total?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static int parseLastPage(dynamic body) {
    final page = _pageBody(body);
    if (page is Map && page['totalPages'] != null) {
      return int.tryParse(page['totalPages'].toString()) ?? 0;
    }
    if (body is Map && body['meta'] is Map) {
      final last = (body['meta'] as Map)['last_page'];
      return int.tryParse(last?.toString() ?? '') ?? 0;
    }
    return 0;
  }
}
