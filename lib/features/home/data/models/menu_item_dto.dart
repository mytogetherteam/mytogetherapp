import '../../../../core/utils/image_utils.dart';

class MenuItemDto {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String title;
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

  const MenuItemDto({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.title,
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
  });

  factory MenuItemDto.fromJson(Map<String, dynamic> json) {
    return MenuItemDto(
      id: json['id']?.toString() ?? '',
      restaurantId: (json['restaurantId'] ?? json['shopId'])?.toString() ?? '',
      restaurantName: json['restaurantName'] ?? json['shopNameEn'] ?? json['shopName'] ?? '',
      title: json['title'] ?? json['nameEn'] ?? json['name'] ?? '',
      price: _parsePrice(json['price']),
      currency: json['currency'] as String? ?? '฿',
      imagePath: ImageUtils.cleanImageUrl(json['imagePath'] ?? json['imageUrl']) ?? '',
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
      restaurantId: (json['restaurantId'] ?? json['shopId'])?.toString() ?? '',
      restaurantName: json['restaurantName'] as String? ?? json['shopNameEn'] as String? ?? json['shopName'] as String? ?? json['shopNameMm'] as String? ?? '',
      title: json['title'] as String? ?? json['nameEn'] as String? ?? json['name'] as String? ?? json['nameMm'] as String? ?? '',
      price: _parsePrice(json['price']),
      currency: json['currency'] as String? ?? '฿',
      imagePath: ImageUtils.cleanImageUrl(json['imagePath'] ?? json['imageUrl']) ?? '',
      category: json['category']?.toString() ?? '',
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
    );
  }

  MenuItemDto copyWith({
    String? id,
    String? restaurantId,
    String? restaurantName,
    String? title,
    double? price,
    String? currency,
    String? imagePath,
    String? category,
    bool? isFavorite,
    double? rating,
    int? reviewCount,
    double? originalPrice,
    String? displayPrice,
    double? distanceKm,
    String? estimatedTime,
    String? deliveryFee,
    String? originalDeliveryFee,
  }) {
    return MenuItemDto(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      title: title ?? this.title,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      originalPrice: originalPrice ?? this.originalPrice,
      displayPrice: displayPrice ?? this.displayPrice,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      originalDeliveryFee: originalDeliveryFee ?? this.originalDeliveryFee,
    );
  }
}
