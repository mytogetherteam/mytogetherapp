import 'models/menu_item_dto.dart';
import 'models/shop_dto.dart' show OperatingHourDto, ShopPaymentTypeDto;
import '../../../core/localization/locale_controller.dart';

class Restaurant {
  final String id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
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

  /// Resolved live against the active language so a language switch updates
  /// already-loaded rails without a refetch. Falls back to the flat [name]
  /// passed in (e.g. mock/static data) when no localized variant is present.
  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  const Restaurant({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
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
    this.isFavorite = false,
    this.paymentTypes = const [],
    this.paymentQrUrl,
    this.deliveryFee,
    this.originalDeliveryFee,
  }) : _name = name;
}
