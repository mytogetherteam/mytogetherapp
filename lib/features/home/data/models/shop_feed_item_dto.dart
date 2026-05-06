import '../../../../core/utils/image_utils.dart';

/// A single food item returned by any of the 5 shop feed endpoints
/// (right-now, for-you, hot-deals, trending, popular-dishes).
class ShopFeedItemDto {
  final int id;
  final String name;
  final String? imageUrl;
  final double price;
  final double? originalPrice;
  final double rating;
  final int reviewCount;
  final int shopId;
  final String shopName;
  final bool isFavorite;
  final String currency;
  final String? displayPrice;
  final double? distanceKm;
  final String? estimatedTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;

  ShopFeedItemDto({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.price,
    this.originalPrice,
    required this.rating,
    required this.reviewCount,
    required this.shopId,
    required this.shopName,
    required this.isFavorite,
    this.currency = '฿',
    this.displayPrice,
    this.distanceKm,
    this.estimatedTime,
    this.deliveryFee,
    this.originalDeliveryFee,
  });

  factory ShopFeedItemDto.fromJson(Map<String, dynamic> json) {
    // Prioritize English name if available
    final name = json['nameEn'] as String? ?? json['name'] as String? ?? json['nameMm'] as String? ?? '';
    final shopName = json['shopNameEn'] as String? ?? json['shopName'] as String? ?? json['shopNameMm'] as String? ?? '';
    
    return ShopFeedItemDto(
      id: json['id'] as int? ?? 0,
      name: name,
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']),
      price: _parsePrice(json['price']),
      originalPrice: json['originalPrice'] != null ? _parsePrice(json['originalPrice']) : null,
      rating: _parsePrice(json['rating'] ?? json['ratingAvg']),
      reviewCount: (json['reviewCount'] ?? json['ratingCount']) as int? ?? 0,
      shopId: json['shopId'] as int? ?? 0,
      shopName: shopName,
      isFavorite: json['isFavorite'] ?? false,
      currency: json['currency'] as String? ?? '฿',
      displayPrice: json['displayPrice'] as String?,
      distanceKm: json['distanceKm'] != null 
          ? double.tryParse(json['distanceKm'].toString()) 
          : (json['shopDistanceKm'] != null ? double.tryParse(json['shopDistanceKm'].toString()) : null),
      estimatedTime: json['estimatedTime']?.toString() ?? json['shopEstimatedTime']?.toString(),
      deliveryFee: _parseDeliveryFee(json),
      originalDeliveryFee: _parseOriginalDeliveryFee(json),
    );
  }

  static String? _parseDeliveryFee(Map<String, dynamic> json) {
    if (json['displayBaseDeliveryFee'] != null) return json['displayBaseDeliveryFee'].toString();
    if (json['displayDeliveryFee'] != null) return json['displayDeliveryFee'].toString();
    return null;
  }

  static String? _parseOriginalDeliveryFee(Map<String, dynamic> json) {
    // If they add original delivery fee later.
    return null;
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > price && price > 0;
}

/// Wraps the top-level API response for any shop feed endpoint
class ShopFeedSectionDto {
  final List<ShopFeedItemDto> items;

  ShopFeedSectionDto({required this.items});

  factory ShopFeedSectionDto.fromJson(Map<String, dynamic> json) {
    // Safely extract data -> items, handling missing or null keys
    final data = json['data'];
    List<dynamic> rawItems = [];
    if (data is Map<String, dynamic>) {
      final it = data['items'];
      if (it is List) rawItems = it;
    }
    return ShopFeedSectionDto(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => ShopFeedItemDto.fromJson(e))
          .toList(),
    );
  }
}
