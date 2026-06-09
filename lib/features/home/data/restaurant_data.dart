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
