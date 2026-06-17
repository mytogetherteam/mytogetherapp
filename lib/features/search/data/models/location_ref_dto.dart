import '../../../../core/localization/locale_controller.dart';

/// A city reference from `GET /api/user/cities`
/// (`UserCitiesController`). Paginated envelope:
/// `{ data: { content: [...], totalElements, ... } }`.
class CityDto {
  final int id;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final bool isActive;

  CityDto({
    required this.id,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.isActive = true,
  });

  String get displayName {
    final name =
        LocaleController.instance.localized(en: nameEn, mm: nameMm, th: nameTh);
    return name.isNotEmpty ? name : (nameEn ?? '');
  }

  factory CityDto.fromJson(Map<String, dynamic> json) {
    return CityDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      isActive: json['isActive'] != false,
    );
  }
}

/// A district reference from `GET /api/user/districts`
/// (`UserDistrictsController`). Carries the parent [city] when present.
class DistrictDto {
  final int id;
  final int? cityId;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final bool isActive;
  final CityDto? city;

  DistrictDto({
    required this.id,
    this.cityId,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.isActive = true,
    this.city,
  });

  String get displayName {
    final name =
        LocaleController.instance.localized(en: nameEn, mm: nameMm, th: nameTh);
    return name.isNotEmpty ? name : (nameEn ?? '');
  }

  factory DistrictDto.fromJson(Map<String, dynamic> json) {
    final cityJson = json['city'];
    return DistrictDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      cityId: (json['cityId'] as num?)?.toInt(),
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      isActive: json['isActive'] != false,
      city: cityJson is Map<String, dynamic>
          ? CityDto.fromJson(cityJson)
          : null,
    );
  }
}
