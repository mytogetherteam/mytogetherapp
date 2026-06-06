import '../../../../core/localization/locale_controller.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/utils/relative_time.dart';

class PlaceGalleryDto {
  final int id;
  final String imageUrl;

  PlaceGalleryDto({required this.id, required this.imageUrl});

  factory PlaceGalleryDto.fromJson(Map<String, dynamic> json) {
    return PlaceGalleryDto(
      id: (json['id'] as num).toInt(),
      imageUrl: resolveMediaUrl(json['imageUrl']?.toString()),
    );
  }
}

class PlaceDto {
  final int id;
  final String titleEn;
  final String? titleMm;
  final String? titleTh;
  final String locationName;
  final String? descriptionEn;
  final String? descriptionMm;
  final String? descriptionTh;
  final String? coverUrl;
  final List<PlaceGalleryDto> photoGallery;
  final String openingTime;
  final String closingTime;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isFavorite;

  PlaceDto({
    required this.id,
    required this.titleEn,
    this.titleMm,
    this.titleTh,
    required this.locationName,
    this.descriptionEn,
    this.descriptionMm,
    this.descriptionTh,
    this.coverUrl,
    required this.photoGallery,
    required this.openingTime,
    required this.closingTime,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isFavorite = false,
  });

  String get displayTitle => LocaleController.instance.localizedOr(
        titleEn,
        en: titleEn,
        mm: titleMm,
        th: titleTh,
      );

  String get displayDescription => LocaleController.instance.localizedOr(
        descriptionEn ?? '',
        en: descriptionEn,
        mm: descriptionMm,
        th: descriptionTh,
      );

  String get coverImage => resolveMediaUrl(coverUrl);

  List<String> get galleryUrls => photoGallery
      .map((g) => g.imageUrl)
      .where((url) => url.isNotEmpty)
      .toList();

  String get formattedDistance => formatDistanceKm(distanceKm);

  String get formattedHours => '$openingTime - $closingTime';

  PlaceDto copyWith({bool? isFavorite, double? distanceKm}) {
    return PlaceDto(
      id: id,
      titleEn: titleEn,
      titleMm: titleMm,
      titleTh: titleTh,
      locationName: locationName,
      descriptionEn: descriptionEn,
      descriptionMm: descriptionMm,
      descriptionTh: descriptionTh,
      coverUrl: coverUrl,
      photoGallery: photoGallery,
      openingTime: openingTime,
      closingTime: closingTime,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory PlaceDto.fromJson(Map<String, dynamic> json) {
    final galleryRaw = json['photoGallery'] ?? json['galleries'];
    return PlaceDto(
      id: (json['id'] as num).toInt(),
      titleEn: json['titleEn']?.toString() ?? '',
      titleMm: json['titleMm']?.toString(),
      titleTh: json['titleTh']?.toString(),
      locationName: json['locationName']?.toString() ?? '',
      descriptionEn: json['descriptionEn']?.toString(),
      descriptionMm: json['descriptionMm']?.toString(),
      descriptionTh: json['descriptionTh']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      photoGallery: galleryRaw is List
          ? galleryRaw
              .whereType<Map<String, dynamic>>()
              .map(PlaceGalleryDto.fromJson)
              .toList()
          : const [],
      openingTime: json['openingTime']?.toString() ?? '09:00',
      closingTime: json['closingTime']?.toString() ?? '21:00',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      isFavorite: json['isFavorite'] == true,
    );
  }
}
