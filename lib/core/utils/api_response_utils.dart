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
      final meta = body['meta'] as Map;
      final last = meta['last_page'] ?? meta['lastPage'];
      return int.tryParse(last?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static int parseCurrentPage(dynamic body, {required int requestedPage}) {
    if (body is Map && body['meta'] is Map) {
      final meta = body['meta'] as Map;
      final page = meta['page'] ?? meta['current_page'];
      final parsed = int.tryParse(page?.toString() ?? '');
      if (parsed != null && parsed >= 0) return parsed;
    }
    final page = _pageBody(body);
    if (page is Map) {
      if (page['page'] != null) {
        final parsed = int.tryParse(page['page'].toString());
        if (parsed != null && parsed >= 0) return parsed;
      }
      if (page['number'] != null) {
        return (int.tryParse(page['number'].toString()) ?? 0) + 1;
      }
    }
    return requestedPage;
  }

  /// Derives continuation from API meta when present; falls back to a full page
  /// of items when meta is absent so plain-list endpoints still paginate.
  static bool hasMoreFromMeta({
    required dynamic body,
    required int currentPage,
    required int itemCount,
    required int pageSize,
    bool zeroBased = false,
  }) {
    bool? springLastFlag;
    final page = _pageBody(body);
    if (page is Map && page.containsKey('last')) {
      springLastFlag = page['last'] != true;
    }

    return hasMorePages(
      page: currentPage,
      lastPage: parseLastPage(body),
      itemCount: itemCount,
      pageSize: pageSize,
      totalCount: parseTotalElements(body),
      zeroBased: zeroBased,
      springLastFlag: springLastFlag,
    );
  }

  /// Shared continuation check for repository meta and feed DTOs.
  static bool hasMorePages({
    required int page,
    required int lastPage,
    required int itemCount,
    required int pageSize,
    int? totalCount,
    bool zeroBased = false,
    bool? springLastFlag,
  }) {
    if (lastPage > 0) {
      return zeroBased ? page + 1 < lastPage : page < lastPage;
    }

    if (totalCount != null && totalCount > 0) {
      final loaded = zeroBased
          ? page * pageSize + itemCount
          : (page - 1) * pageSize + itemCount;
      return loaded < totalCount;
    }

    if (springLastFlag != null) return springLastFlag;

    return itemCount >= pageSize;
  }
}

/// Generic paginated API payload with explicit [hasMore] from server meta.
class PagedApiResult<T> {
  final List<T> items;
  final bool hasMore;

  const PagedApiResult({required this.items, required this.hasMore});

  factory PagedApiResult.fromBody({
    required dynamic body,
    required int page,
    required int pageSize,
    required List<T> items,
    bool zeroBased = false,
  }) {
    final currentPage = ApiResponseUtils.parseCurrentPage(
      body,
      requestedPage: page,
    );
    return PagedApiResult(
      items: items,
      hasMore: ApiResponseUtils.hasMoreFromMeta(
        body: body,
        currentPage: currentPage,
        itemCount: items.length,
        pageSize: pageSize,
        zeroBased: zeroBased,
      ),
    );
  }
}
