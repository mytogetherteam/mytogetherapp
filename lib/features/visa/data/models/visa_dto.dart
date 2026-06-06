import '../../../../core/localization/locale_controller.dart';
import '../../../../core/network/media_url.dart';

class VisaCategoryDto {
  final int id;
  final String title;
  final String section;
  final int displayOrder;

  VisaCategoryDto({
    required this.id,
    required this.title,
    required this.section,
    required this.displayOrder,
  });

  factory VisaCategoryDto.fromJson(Map<String, dynamic> json) {
    return VisaCategoryDto(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      section: json['section']?.toString() ?? 'VISA_TYPES',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class VisaDto {
  final int id;
  final int visaCategoryId;
  final VisaCategoryDto? visaCategory;
  final String titleEn;
  final String? titleMm;
  final String? titleTh;
  final String? subtitleEn;
  final String? subtitleMm;
  final String? subtitleTh;
  final String? descriptionEn;
  final String? descriptionMm;
  final String? descriptionTh;
  final String? iconUrl;
  final String? bannerUrl;
  final String? linkUrl;
  final int displayOrder;

  VisaDto({
    required this.id,
    required this.visaCategoryId,
    this.visaCategory,
    required this.titleEn,
    this.titleMm,
    this.titleTh,
    this.subtitleEn,
    this.subtitleMm,
    this.subtitleTh,
    this.descriptionEn,
    this.descriptionMm,
    this.descriptionTh,
    this.iconUrl,
    this.bannerUrl,
    this.linkUrl,
    required this.displayOrder,
  });

  String get displayTitle => LocaleController.instance.localizedOr(
        titleEn,
        en: titleEn,
        mm: titleMm,
        th: titleTh,
      );

  String get displaySubtitle => LocaleController.instance.localizedOr(
        subtitleEn ?? '',
        en: subtitleEn,
        mm: subtitleMm,
        th: subtitleTh,
      );

  String get displayDescription => LocaleController.instance.localizedOr(
        descriptionEn ?? displaySubtitle,
        en: descriptionEn,
        mm: descriptionMm,
        th: descriptionTh,
      );

  String? get resolvedImageUrl {
    final banner = resolveMediaUrl(bannerUrl);
    if (banner.isNotEmpty) return banner;
    final icon = resolveMediaUrl(iconUrl);
    return icon.isNotEmpty ? icon : null;
  }

  factory VisaDto.fromJson(Map<String, dynamic> json) {
    return VisaDto(
      id: (json['id'] as num).toInt(),
      visaCategoryId: (json['visaCategoryId'] as num?)?.toInt() ?? 0,
      visaCategory: json['visaCategory'] is Map<String, dynamic>
          ? VisaCategoryDto.fromJson(
              json['visaCategory'] as Map<String, dynamic>,
            )
          : null,
      titleEn: json['titleEn']?.toString() ?? '',
      titleMm: json['titleMm']?.toString(),
      titleTh: json['titleTh']?.toString(),
      subtitleEn: json['subtitleEn']?.toString(),
      subtitleMm: json['subtitleMm']?.toString(),
      subtitleTh: json['subtitleTh']?.toString(),
      descriptionEn: json['descriptionEn']?.toString(),
      descriptionMm: json['descriptionMm']?.toString(),
      descriptionTh: json['descriptionTh']?.toString(),
      iconUrl: json['iconUrl']?.toString(),
      bannerUrl: json['bannerUrl']?.toString(),
      linkUrl: json['linkUrl']?.toString(),
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
