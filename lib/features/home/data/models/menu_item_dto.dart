import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';

class MenuItemDto {
  final String id;
  final String restaurantId;
  final String _restaurantName;
  final String? restaurantNameEn;
  final String? restaurantNameMm;
  final String? restaurantNameTh;
  final String _title;
  final String? titleEn;
  final String? titleMm;
  final String? titleTh;
  final double price;
  final String currency;
  final String imagePath;
  final String category;
  final bool isFavorite;
  final double rating;
  final int reviewCount;
  final double? originalPrice;
  final String? displayPrice;
  final double? distanceKm;
  final String? estimatedTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final bool isAvailable;
  final String publishStatus;

  String get restaurantName => LocaleController.instance.localizedOr(
        _restaurantName,
        en: restaurantNameEn,
        mm: restaurantNameMm,
        th: restaurantNameTh,
      );

  String get title => LocaleController.instance
      .localizedOr(_title, en: titleEn, mm: titleMm, th: titleTh);

  MenuItemDto({
    required this.id,
    required this.restaurantId,
    required String restaurantName,
    this.restaurantNameEn,
    this.restaurantNameMm,
    this.restaurantNameTh,
    required String title,
    this.titleEn,
    this.titleMm,
    this.titleTh,
    required this.price,
    required this.currency,
    required this.imagePath,
    required this.category,
    this.isFavorite = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.originalPrice,
    this.displayPrice,
    this.distanceKm,
    this.estimatedTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    this.isAvailable = true,
    this.publishStatus = 'PUBLISHED',
  })  : _restaurantName = restaurantName,
        _title = title;

  factory MenuItemDto.fromJson(Map<String, dynamic> json) {
    return MenuItemDto(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName'] ?? '',
      title: json['title'] ?? '',
      price: _parsePrice(json['price']),
      currency: json['currency'] as String? ?? '฿',
      imagePath: ImageUtils.cleanImageUrl(json['imagePath']) ?? '',
      category: json['category'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
      rating: _parsePrice(json['rating']),
      reviewCount: json['reviewCount'] ?? json['ratingCount'] ?? 0,
      originalPrice: json['originalPrice'] != null ? _parsePrice(json['originalPrice']) : null,
      displayPrice: json['displayPrice'] as String?,
      distanceKm: json['distanceKm'] != null 
          ? double.tryParse(json['distanceKm'].toString()) 
          : (json['shopDistanceKm'] != null ? double.tryParse(json['shopDistanceKm'].toString()) : null),
      estimatedTime: json['estimatedTime']?.toString() ?? json['shopEstimatedTime']?.toString(),
      deliveryFee: _parseDeliveryFee(json),
      originalDeliveryFee: null, // Depending on if api adds it
      isAvailable: json['isAvailable'] as bool? ?? true,
      publishStatus: json['publishStatus'] as String? ?? 'PUBLISHED',
    );
  }

  static String? _parseDeliveryFee(Map<String, dynamic> json) {
    if (json['displayBaseDeliveryFee'] != null) return json['displayBaseDeliveryFee'] as String;
    if (json['displayDeliveryFee'] != null) return json['displayDeliveryFee'] as String;
    return null;
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'title': title,
      'price': price,
      'currency': currency,
      'imagePath': imagePath,
      'category': category,
      'isFavorite': isFavorite,
      'rating': rating,
       'originalPrice': originalPrice,
      'displayPrice': displayPrice,
    };
  }

  factory MenuItemDto.fromDishJson(Map<String, dynamic> json) {
    return MenuItemDto(
      id: json['id']?.toString() ?? '',
      restaurantId: json['shopId']?.toString() ?? '',
      restaurantName: (json['shopNameEn'] as String? ?? json['shopName'] as String?) ?? '',
      restaurantNameEn: json['shopNameEn'] as String? ?? json['shopName'] as String?,
      restaurantNameMm: json['shopNameMm'] as String?,
      restaurantNameTh: json['shopNameTh'] as String?,
      title: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      titleEn: json['nameEn'] as String? ?? json['name'] as String?,
      titleMm: json['nameMm'] as String?,
      titleTh: json['nameTh'] as String?,
      price: _parsePrice(json['price']),
      currency: json['currency'] as String? ?? '฿',
      imagePath: ImageUtils.cleanImageUrl(json['imageUrl']) ?? '',
      category: '',
      isFavorite: json['isFavorite'] ?? false,
      rating: _parsePrice(json['rating']),
      reviewCount: json['reviewCount'] ?? json['ratingCount'] ?? 0,
      originalPrice: json['originalPrice'] != null ? _parsePrice(json['originalPrice']) : null,
      displayPrice: json['displayPrice'] as String?,
      distanceKm: json['distanceKm'] != null 
          ? double.tryParse(json['distanceKm'].toString()) 
          : (json['shopDistanceKm'] != null ? double.tryParse(json['shopDistanceKm'].toString()) : null),
      estimatedTime: json['estimatedTime']?.toString() ?? json['shopEstimatedTime']?.toString(),
      deliveryFee: _parseDeliveryFee(json),
      isAvailable: json['isAvailable'] as bool? ?? true,
      publishStatus: json['publishStatus'] as String? ?? 'PUBLISHED',
    );
  }
}
