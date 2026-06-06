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

  /// News / item-post feeds return `{ content, totalElements, ... }` directly.
  static List<T> parseContentPage<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (body is Map && body['content'] is List) {
      return (body['content'] as List)
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }
    return const [];
  }

  static int parseTotalElements(dynamic body) {
    if (body is Map && body['totalElements'] != null) {
      return int.tryParse(body['totalElements'].toString()) ?? 0;
    }
    if (body is Map && body['meta'] is Map) {
      final total = (body['meta'] as Map)['total'];
      return int.tryParse(total?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static int parseLastPage(dynamic body) {
    if (body is Map && body['totalPages'] != null) {
      return int.tryParse(body['totalPages'].toString()) ?? 0;
    }
    if (body is Map && body['meta'] is Map) {
      final last = (body['meta'] as Map)['last_page'];
      return int.tryParse(last?.toString() ?? '') ?? 0;
    }
    return 0;
  }
}
