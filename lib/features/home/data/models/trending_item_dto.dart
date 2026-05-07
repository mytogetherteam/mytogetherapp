import '../../../../core/utils/image_utils.dart';

class TrendingItemDto {
  final int id;
  final String name;
  final String imageUrl;
  final int shopId;
  final String shopName;
  final double price;
  final double rating;
  final int reviewCount;
  final bool isFavorite;
  final String currency;
  final double? originalPrice;
  final String? displayPrice;
  final double? distanceKm;
  final String? estimatedTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final bool isAvailable;
  final String publishStatus;

  TrendingItemDto({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.shopId,
    required this.shopName,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.isFavorite,
    required this.currency,
    this.originalPrice,
    this.displayPrice,
    this.distanceKm,
    this.estimatedTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    this.isAvailable = true,
    this.publishStatus = 'PUBLISHED',
  });

  factory TrendingItemDto.fromJson(Map<String, dynamic> json) {
    // Prioritize English name if available
    final name = json['nameEn'] as String? ?? json['name'] as String? ?? json['nameMm'] as String? ?? '';
    final shopName = json['shopNameEn'] as String? ?? json['shopName'] as String? ?? json['shopNameMm'] as String? ?? '';
    
    return TrendingItemDto(
      id: json['id'] as int? ?? 0,
      name: name,
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']) ?? '',
      shopId: json['shopId'] as int? ?? 0,
      shopName: shopName,
      price: _parsePrice(json['price']),
      rating: _parsePrice(json['rating']),
      reviewCount: json['reviewCount'] as int? ?? 0,
      isFavorite: json['isFavorite'] ?? false,
      currency: json['currency'] as String? ?? '฿',
      originalPrice: json['originalPrice'] != null ? _parsePrice(json['originalPrice']) : null,
      displayPrice: json['displayPrice'] as String?,
      distanceKm: json['distanceKm'] != null 
          ? (json['distanceKm'] is num 
              ? (json['distanceKm'] as num).toDouble() 
              : double.tryParse(json['distanceKm'].toString()))
          : (json['shopDistanceKm'] != null ? double.tryParse(json['shopDistanceKm'].toString()) : null),
      estimatedTime: json['estimatedTime']?.toString() ?? json['shopEstimatedTime']?.toString(),
      deliveryFee: _parseDeliveryFee(json),
      originalDeliveryFee: _parseOriginalDeliveryFee(json),
      isAvailable: json['isAvailable'] as bool? ?? true,
      publishStatus: json['publishStatus'] as String? ?? 'PUBLISHED',
    );
  }

  static String? _parseDeliveryFee(Map<String, dynamic> json) {
    if (json['displayBaseDeliveryFee'] != null) return json['displayBaseDeliveryFee'] as String;
    if (json['displayDeliveryFee'] != null) return json['displayDeliveryFee'] as String;
    if (json['deliveryFee'] != null) return json['deliveryFee'] as String;
    return null;
  }

  static String? _parseOriginalDeliveryFee(Map<String, dynamic> json) {
    if (json['originalDeliveryFee'] != null) return json['originalDeliveryFee'] as String;
    return null;
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class TrendingSectionDto {
  final String title;
  final String description;
  final List<TrendingItemDto> items;
  final int totalCount;

  TrendingSectionDto({
    required this.title,
    required this.description,
    required this.items,
    required this.totalCount,
  });

  factory TrendingSectionDto.fromJson(Map<String, dynamic> json) {
    return TrendingSectionDto(
      title: json['title'] as String? ?? 'Trending Nearby',
      description: json['description'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => TrendingItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }
}
