/// Admin-controlled home discount carousel configuration returned by
/// `GET /api/user/home-discount-section`.
///
/// The app must NOT hardcode the discount percentage or the section title — it
/// reads them from this config first, then loads the actual carousel items from
/// `GET /api/user/menu-items/discount`.
class HomeDiscountSectionDto {
  final int id;

  /// Nullable. May contain a `{}` placeholder for the percentage, e.g.
  /// "Summer {} Off". The placeholder is resolved server-side — never on the
  /// client.
  final String? title;

  final int discountPercent;

  final DateTime? startTime;
  final DateTime? endTime;

  /// One of: `active`, `scheduled`, `expired`.
  final String status;

  const HomeDiscountSectionDto({
    required this.id,
    required this.title,
    required this.discountPercent,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  bool get isActive => status == 'active';

  /// Whether the title is usable as a `sectionTitle` query param (non-null and
  /// non-empty after trimming).
  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  factory HomeDiscountSectionDto.fromJson(Map<String, dynamic> json) {
    return HomeDiscountSectionDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString(),
      discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
      startTime: _parseDate(json['startTime']),
      endTime: _parseDate(json['endTime']),
      status: json['status']?.toString() ?? 'expired',
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

/// Envelope `data` for `GET /api/user/home-discount-section`.
class HomeDiscountSectionListDto {
  final List<HomeDiscountSectionDto> sections;

  /// The single currently-running section (status == "active"), or null. Use
  /// this as the shortcut for the home carousel.
  final HomeDiscountSectionDto? activeSection;

  const HomeDiscountSectionListDto({
    required this.sections,
    required this.activeSection,
  });

  static const HomeDiscountSectionListDto empty = HomeDiscountSectionListDto(
    sections: [],
    activeSection: null,
  );

  factory HomeDiscountSectionListDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final rawSections = data['sections'];
    final sections = rawSections is List
        ? rawSections
            .whereType<Map<String, dynamic>>()
            .map(HomeDiscountSectionDto.fromJson)
            .toList()
        : <HomeDiscountSectionDto>[];

    final rawActive = data['activeSection'];
    final activeSection = rawActive is Map<String, dynamic>
        ? HomeDiscountSectionDto.fromJson(rawActive)
        : null;

    return HomeDiscountSectionListDto(
      sections: sections,
      activeSection: activeSection,
    );
  }
}
