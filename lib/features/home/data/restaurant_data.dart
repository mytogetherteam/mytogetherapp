import 'models/menu_item_dto.dart';
import 'models/shop_dto.dart'
    show OperatingHourDto, ShopPaymentTypeDto, LocalTimeDto;
import '../../../core/localization/locale_controller.dart';

class Restaurant {
  final String id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? descriptionEn;
  final String? descriptionMm;
  final String? descriptionTh;
  final String category;
  final double rating;
  final int reviewCount;
  final String distance;
  final String imagePath;
  final String logoPath;
  final String deliveryTime;
  final String status;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;
  final bool isFavorite;
  final List<MenuItemDto> popularDishes;
  final List<MenuItemDto> recommendations;
  final List<MenuItemDto> hotDeals;
  final List<ShopPaymentTypeDto> paymentTypes;
  final String? paymentQrUrl;
  final String? deliveryFee;
  final String? originalDeliveryFee;

  // New fields for Overview Page
  final String? address;
  final String? addressMm;
  final String? addressTh;
  final String? addressEn;
  final String? phone;
  final String? email;
  final String? googleMapsLink;
  final List<OperatingHourDto> operatingHours;

  // Amenities / features
  final bool hasParking;
  final bool hasWifi;
  final bool isHalal;
  final bool isVegetarian;

  /// Resolved live against the active language so a language switch updates
  /// already-loaded rails without a refetch. Falls back to the flat [name]
  /// passed in (e.g. mock/static data) when no localized variant is present.
  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  /// Localized shop description, empty when none is available.
  String get description => LocaleController.instance
      .localized(en: descriptionEn, mm: descriptionMm, th: descriptionTh);

  /// Whether at least one amenity is available (used to hide the section).
  bool get hasAnyFeature => hasParking || hasWifi || isHalal || isVegetarian;

  /// Live open/closed state computed from [operatingHours] against the device
  /// clock. Falls back to the API [status] flag when no schedule is available.
  OpeningStatus get openingStatus => OpeningStatus.fromHours(operatingHours);

  const Restaurant({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.descriptionEn,
    this.descriptionMm,
    this.descriptionTh,
    required this.category,
    required this.rating,
    this.reviewCount = 0,
    required this.distance,
    required this.imagePath,
    required this.logoPath,
    required this.deliveryTime,
    required this.status,
    this.latitude,
    this.longitude,
    this.imageUrls = const <String>[],
    this.popularDishes = const <MenuItemDto>[],
    this.recommendations = const <MenuItemDto>[],
    this.hotDeals = const <MenuItemDto>[],
    this.address,
    this.addressMm,
    this.addressTh,
    this.addressEn,
    this.phone,
    this.email,
    this.googleMapsLink,
    this.operatingHours = const [],
    this.hasParking = false,
    this.hasWifi = false,
    this.isHalal = false,
    this.isVegetarian = false,
    this.isFavorite = false,
    this.paymentTypes = const [],
    this.paymentQrUrl,
    this.deliveryFee,
    this.originalDeliveryFee,
  }) : _name = name;

  Restaurant copyWith({
    String? id,
    String? name,
    String? nameEn,
    String? nameMm,
    String? nameTh,
    String? category,
    double? rating,
    int? reviewCount,
    String? distance,
    String? imagePath,
    String? logoPath,
    String? deliveryTime,
    String? status,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
    bool? isFavorite,
    List<MenuItemDto>? popularDishes,
    List<MenuItemDto>? recommendations,
    List<MenuItemDto>? hotDeals,
    List<ShopPaymentTypeDto>? paymentTypes,
    String? paymentQrUrl,
    String? deliveryFee,
    String? originalDeliveryFee,
    String? address,
    String? addressMm,
    String? addressTh,
    String? addressEn,
    String? phone,
    String? email,
    String? googleMapsLink,
    List<OperatingHourDto>? operatingHours,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? _name,
      nameEn: nameEn ?? this.nameEn,
      nameMm: nameMm ?? this.nameMm,
      nameTh: nameTh ?? this.nameTh,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distance: distance ?? this.distance,
      imagePath: imagePath ?? this.imagePath,
      logoPath: logoPath ?? this.logoPath,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrls: imageUrls ?? this.imageUrls,
      isFavorite: isFavorite ?? this.isFavorite,
      popularDishes: popularDishes ?? this.popularDishes,
      recommendations: recommendations ?? this.recommendations,
      hotDeals: hotDeals ?? this.hotDeals,
      paymentTypes: paymentTypes ?? this.paymentTypes,
      paymentQrUrl: paymentQrUrl ?? this.paymentQrUrl,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      originalDeliveryFee: originalDeliveryFee ?? this.originalDeliveryFee,
      address: address ?? this.address,
      addressMm: addressMm ?? this.addressMm,
      addressTh: addressTh ?? this.addressTh,
      addressEn: addressEn ?? this.addressEn,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      googleMapsLink: googleMapsLink ?? this.googleMapsLink,
      operatingHours: operatingHours ?? this.operatingHours,
    );
  }
}

/// Result of computing a shop's open/closed state from its weekly schedule.
class OpeningStatus {
  /// Whether a usable weekly schedule was available. When false the caller
  /// should fall back to the API-provided `isOpen` flag.
  final bool hasSchedule;
  final bool isOpen;

  /// When closed, the next time the shop opens (ISO weekday 1=Mon..7=Sun).
  final int? nextOpenDayIso;
  final int? nextOpenHour;
  final int? nextOpenMinute;

  /// True when the next opening is later on the current day.
  final bool nextOpenIsToday;

  const OpeningStatus({
    required this.hasSchedule,
    required this.isOpen,
    this.nextOpenDayIso,
    this.nextOpenHour,
    this.nextOpenMinute,
    this.nextOpenIsToday = false,
  });

  /// Maps a backend `dayOfWeek` (int `0`=Sun..`6`=Sat, or a weekday name) to an
  /// ISO weekday (1=Mon..7=Sun). Returns `8` for unrecognized values.
  static int _isoDay(String day) {
    final number = int.tryParse(day);
    if (number != null) {
      if (number == 0) return 7;
      if (number >= 1 && number <= 7) return number;
      return 8;
    }
    switch (day.toUpperCase()) {
      case 'MONDAY':
        return 1;
      case 'TUESDAY':
        return 2;
      case 'WEDNESDAY':
        return 3;
      case 'THURSDAY':
        return 4;
      case 'FRIDAY':
        return 5;
      case 'SATURDAY':
        return 6;
      case 'SUNDAY':
        return 7;
      default:
        return 8;
    }
  }

  static int _minutesOf(LocalTimeDto t) => t.hour * 60 + t.minute;

  /// Computes the live status from [hours]. [now] is injectable for testing.
  static OpeningStatus fromHours(
    List<OperatingHourDto> hours, {
    DateTime? now,
  }) {
    final map = <int, OperatingHourDto>{};
    for (final h in hours) {
      final iso = _isoDay(h.dayOfWeek);
      if (iso >= 1 && iso <= 7) map[iso] = h;
    }
    if (map.isEmpty) {
      return const OpeningStatus(hasSchedule: false, isOpen: false);
    }

    final current = now ?? DateTime.now();
    final int todayIso = current.weekday; // 1..7
    final int nowMin = current.hour * 60 + current.minute;

    // 1) Open right now? Handle same-day and overnight (close <= open) windows.
    bool openNow = false;
    final today = map[todayIso];
    if (today != null &&
        !today.isClosed &&
        today.openingTime != null &&
        today.closingTime != null) {
      final open = _minutesOf(today.openingTime!);
      final close = _minutesOf(today.closingTime!);
      if (close > open) {
        openNow = nowMin >= open && nowMin < close;
      } else if (close < open) {
        openNow = nowMin >= open || nowMin < close;
      }
    }
    // Yesterday's overnight window spilling past midnight into today.
    if (!openNow) {
      final yIso = todayIso == 1 ? 7 : todayIso - 1;
      final y = map[yIso];
      if (y != null &&
          !y.isClosed &&
          y.openingTime != null &&
          y.closingTime != null) {
        final open = _minutesOf(y.openingTime!);
        final close = _minutesOf(y.closingTime!);
        if (close < open && nowMin < close) openNow = true;
      }
    }

    if (openNow) {
      return const OpeningStatus(hasSchedule: true, isOpen: true);
    }

    // 2) Closed — find the next opening within the coming week.
    for (int offset = 0; offset < 8; offset++) {
      final iso = ((todayIso - 1 + offset) % 7) + 1;
      final entry = map[iso];
      if (entry == null || entry.isClosed || entry.openingTime == null) {
        continue;
      }
      final open = _minutesOf(entry.openingTime!);
      if (offset == 0 && open <= nowMin) continue; // already passed today
      return OpeningStatus(
        hasSchedule: true,
        isOpen: false,
        nextOpenDayIso: iso,
        nextOpenHour: entry.openingTime!.hour,
        nextOpenMinute: entry.openingTime!.minute,
        nextOpenIsToday: offset == 0,
      );
    }

    return const OpeningStatus(hasSchedule: true, isOpen: false);
  }
}
