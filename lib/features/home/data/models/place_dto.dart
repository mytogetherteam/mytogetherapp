import '../../../../core/localization/locale_controller.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../core/utils/time_formatter.dart';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageUrl': imageUrl,
  };
}

class PricingPlanDto {
  final String? id;
  final String title;
  final double price;
  final String unit;
  final String? timeSlot;
  final String? note;
  final bool isPopular;

  const PricingPlanDto({
    this.id,
    required this.title,
    required this.price,
    this.unit = 'hr',
    this.timeSlot,
    this.note,
    this.isPopular = false,
  });

  String get formattedPrice {
    final priceStr = price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);
    return '฿$priceStr${unit.isNotEmpty ? '/$unit' : ''}';
  }

  factory PricingPlanDto.fromJson(Map<String, dynamic> json) {
    return PricingPlanDto(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'hr',
      timeSlot: json['timeSlot']?.toString(),
      note: json['note']?.toString(),
      isPopular: json['isPopular'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    'price': price,
    'unit': unit,
    if (timeSlot != null) 'timeSlot': timeSlot,
    if (note != null) 'note': note,
    'isPopular': isPopular,
  };
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
  final String? phoneNumber;
  final String? websiteUrl;
  final String? googleMapsUrl;
  final List<String> activities;
  final List<String> amenities;
  final List<PricingPlanDto> pricingPlans;

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
    this.phoneNumber,
    this.websiteUrl,
    this.googleMapsUrl,
    this.activities = const [],
    this.amenities = const [],
    this.pricingPlans = const [],
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

  String get formattedHours => TimeFormatter.normalizeDisplay(
        '$openingTime - $closingTime',
      );

  String? get startingPrice {
    if (pricingPlans.isEmpty) return null;
    double minPrice = double.infinity;
    String minUnit = 'hr';
    for (final plan in pricingPlans) {
      if (plan.price < minPrice && plan.price > 0) {
        minPrice = plan.price;
        minUnit = plan.unit;
      }
    }
    if (minPrice == double.infinity) return null;
    final priceStr = minPrice % 1 == 0 ? minPrice.toInt().toString() : minPrice.toStringAsFixed(0);
    return 'From ฿$priceStr${minUnit.isNotEmpty ? '/$minUnit' : ''}';
  }

  String? get primaryActivity => activities.isNotEmpty ? activities.first : null;

  PlaceDto copyWith({
    bool? isFavorite,
    double? distanceKm,
    List<String>? activities,
    List<String>? amenities,
    List<PricingPlanDto>? pricingPlans,
    String? phoneNumber,
    String? websiteUrl,
    String? googleMapsUrl,
  }) {
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
      phoneNumber: phoneNumber ?? this.phoneNumber,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      activities: activities ?? this.activities,
      amenities: amenities ?? this.amenities,
      pricingPlans: pricingPlans ?? this.pricingPlans,
    );
  }

  factory PlaceDto.fromJson(Map<String, dynamic> json) {
    final galleryRaw = json['photoGallery'] ?? json['galleries'];

    List<PricingPlanDto> plans = [];
    final rawPlans = json['pricingPlans'];
    if (rawPlans is List) {
      plans = rawPlans
          .whereType<Map<String, dynamic>>()
          .map(PricingPlanDto.fromJson)
          .toList();
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

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
      phoneNumber: json['phoneNumber']?.toString(),
      websiteUrl: json['websiteUrl']?.toString(),
      googleMapsUrl: json['googleMapsUrl']?.toString(),
      activities: parseStringList(json['activities']),
      amenities: parseStringList(json['amenities']),
      pricingPlans: plans,
    );
  }
}
