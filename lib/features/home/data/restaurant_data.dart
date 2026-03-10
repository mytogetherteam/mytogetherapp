import 'models/menu_item_dto.dart';
import 'models/shop_dto.dart' show OperatingHourDto, ShopPaymentTypeDto;

class Restaurant {
  final String id;
  final String name;
  final String category;
  final double rating;
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

  // New fields for Overview Page
  final String? address;
  final String? addressMm;
  final String? addressTh;
  final String? addressEn;
  final String? phone;
  final String? email;
  final String? googleMapsLink;
  final List<OperatingHourDto> operatingHours;

  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
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
  });
}
