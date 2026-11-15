import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_utils.dart';
import '../models/visa_dto.dart';

class VisaSectionData {
  final List<VisaCategoryDto> categories;
  final Map<int, List<VisaDto>> visasByCategory;

  const VisaSectionData({
    required this.categories,
    required this.visasByCategory,
  });
}

class VisaRepository {
  static final VisaRepository instance = VisaRepository._();
  VisaRepository._();

  final Dio _dio = ApiClient().dio;

  /// Cache TTL to avoid redundant server requests and reduce bandwidth costs.
  static const Duration _cacheTtl = Duration(minutes: 15);
  static const String _diskCachePrefix = 'visa_section_cache_v1_';

  final Map<String, VisaSectionData> _sectionCache = {};
  final Map<String, DateTime> _sectionCacheTime = {};
  final Map<String, Future<VisaSectionData>> _inFlightSections = {};
  final Map<int, VisaDto> _visaByIdCache = {};

  bool _isFresh(DateTime? fetchedAt) {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < _cacheTtl;
  }

  void _indexVisas(VisaSectionData data) {
    for (final list in data.visasByCategory.values) {
      for (final visa in list) {
        _visaByIdCache[visa.id] = visa;
      }
    }
  }

  VisaSectionData _parseSectionPayload(
    dynamic categoriesRaw,
    dynamic visasRaw,
  ) {
    final categories = ApiResponseUtils.parseDataList(
      categoriesRaw,
      VisaCategoryDto.fromJson,
    )..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final visas = ApiResponseUtils.parseDataList(
      visasRaw,
      VisaDto.fromJson,
    )..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final grouped = <int, List<VisaDto>>{};
    for (final visa in visas) {
      grouped.putIfAbsent(visa.visaCategoryId, () => []).add(visa);
    }

    final sectionData = VisaSectionData(
      categories: categories,
      visasByCategory: grouped,
    );
    _indexVisas(sectionData);
    return sectionData;
  }

  /// Returns cached section data synchronously if available in memory.
  VisaSectionData? getCachedSection(String section) => _sectionCache[section];

  Future<VisaSectionData> loadSection(
    String section, {
    int size = 100,
    bool forceRefresh = false,
  }) async {
    // 1. Fast path: valid in-memory cache
    if (!forceRefresh &&
        _sectionCache.containsKey(section) &&
        _isFresh(_sectionCacheTime[section])) {
      return _sectionCache[section]!;
    }

    // 2. Deduplicate concurrent requests for the same section
    if (!forceRefresh && _inFlightSections.containsKey(section)) {
      return _inFlightSections[section]!;
    }

    final future = _loadSectionInternal(
      section,
      size: size,
      forceRefresh: forceRefresh,
    );
    _inFlightSections[section] = future;
    try {
      return await future;
    } finally {
      _inFlightSections.remove(section);
    }
  }

  Future<VisaSectionData> _loadSectionInternal(
    String section, {
    required int size,
    required bool forceRefresh,
  }) async {
    // 3. Check persistent disk cache before hitting the network
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (!forceRefresh) {
        final rawJson = prefs.getString('$_diskCachePrefix$section');
        if (rawJson != null && rawJson.isNotEmpty) {
          final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
          final tsMillis = (decoded['ts'] as num?)?.toInt();
          final fetchedAt = tsMillis != null
              ? DateTime.fromMillisecondsSinceEpoch(tsMillis)
              : null;
          if (_isFresh(fetchedAt)) {
            final data = _parseSectionPayload(
              decoded['categories'],
              decoded['visas'],
            );
            _sectionCache[section] = data;
            _sectionCacheTime[section] = fetchedAt!;
            return data;
          }
        }
      }
    } catch (_) {
      // Ignore disk cache read errors and proceed to network
    }

    // 4. Fetch from server and update both memory and disk cache
    try {
      final results = await Future.wait([
        _dio.get(
          '${ApiClient.apiPrefix}/user/visa/categories/list',
          queryParameters: {'section': section},
        ),
        _dio.get(
          '${ApiClient.apiPrefix}/user/visa',
          queryParameters: {'section': section, 'page': 1, 'size': size},
        ),
      ]);

      final categoriesRaw = results[0].data;
      final visasRaw = results[1].data;
      final data = _parseSectionPayload(categoriesRaw, visasRaw);
      final now = DateTime.now();

      _sectionCache[section] = data;
      _sectionCacheTime[section] = now;

      try {
        prefs ??= await SharedPreferences.getInstance();
        await prefs.setString(
          '$_diskCachePrefix$section',
          jsonEncode({
            'ts': now.millisecondsSinceEpoch,
            'categories': categoriesRaw,
            'visas': visasRaw,
          }),
        );
      } catch (_) {}

      return data;
    } catch (e) {
      // 5. Offline / error fallback: return stale memory or disk cache if available
      if (_sectionCache.containsKey(section)) {
        return _sectionCache[section]!;
      }
      try {
        prefs ??= await SharedPreferences.getInstance();
        final rawJson = prefs.getString('$_diskCachePrefix$section');
        if (rawJson != null && rawJson.isNotEmpty) {
          final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
          final data = _parseSectionPayload(
            decoded['categories'],
            decoded['visas'],
          );
          _sectionCache[section] = data;
          return data;
        }
      } catch (_) {}
      rethrow;
    }
  }

  Future<VisaDto?> fetchOne(int id, {bool forceRefresh = false}) async {
    if (!forceRefresh && _visaByIdCache.containsKey(id)) {
      return _visaByIdCache[id];
    }
    final response = await _dio.get('${ApiClient.apiPrefix}/user/visa/$id');
    final visa = ApiResponseUtils.parseDataObject(
      response.data,
      VisaDto.fromJson,
    );
    if (visa != null) {
      _visaByIdCache[visa.id] = visa;
    }
    return visa;
  }

  void clearCache() {
    _sectionCache.clear();
    _sectionCacheTime.clear();
    _visaByIdCache.clear();
  }
}
