import '../../../../core/localization/locale_controller.dart';

class TrendingItemDto {
  final int id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String imageUrl;
  final int shopId;
  final String _shopName;
  final String? shopNameEn;
  final String? shopNameMm;
  final String? shopNameTh;
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

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  String get shopName => LocaleController.instance
      .localizedOr(_shopName, en: shopNameEn, mm: shopNameMm, th: shopNameTh);

  TrendingItemDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.imageUrl,
    required this.shopId,
    required String shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopNameTh,
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
  })  : _name = name,
        _shopName = shopName;

  factory TrendingItemDto.fromJson(Map<String, dynamic> json) {
    // `GET /user/search/trending-nearby` nests shop + rating; public feed is flat.
    final shop = json['shop'];
    final shopMap = shop is Map<String, dynamic> ? shop : null;
    final ratingObj = shopMap?['rating'];
    final ratingMap = ratingObj is Map<String, dynamic> ? ratingObj : null;

    final nameEn = json['nameEn'] as String? ?? json['name'] as String?;
    final nameMm = json['nameMm'] as String?;
    final nameTh = json['nameTh'] as String?;

    final shopNameEn = json['shopNameEn'] as String? ??
        json['shopName'] as String? ??
        shopMap?['nameEn'] as String?;
    final shopNameMm =
        json['shopNameMm'] as String? ?? shopMap?['nameMm'] as String?;
    final shopNameTh =
        json['shopNameTh'] as String? ?? shopMap?['nameTh'] as String?;

    final shopId = (json['shopId'] as num?)?.toInt() ??
        (shopMap?['id'] as num?)?.toInt() ??
        0;

    final rating = _parsePrice(
      json['rating'] ?? ratingMap?['avg'] ?? shopMap?['ratingAvg'],
    );
    final reviewCount = (json['reviewCount'] as num?)?.toInt() ??
        (ratingMap?['count'] as num?)?.toInt() ??
        (shopMap?['ratingCount'] as num?)?.toInt() ??
        0;

    final originalPrice = json['originalPrice'] != null
        ? _parsePrice(json['originalPrice'])
        : null;
    final price = json['price'] != null
        ? _parsePrice(json['price'])
        : _effectivePrice(
            originalPrice,
            json['discountAmount'],
            json['discountPercentage'],
          );

    double? distanceKm;
    final rawDistance =
        json['distanceKm'] ?? shopMap?['distanceKm'] ?? json['shopDistanceKm'];
    if (rawDistance is num) {
      distanceKm = rawDistance.toDouble();
    } else if (rawDistance != null) {
      distanceKm = double.tryParse(rawDistance.toString());
    }

    return TrendingItemDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: nameEn ?? '',
      nameEn: nameEn,
      nameMm: nameMm,
      nameTh: nameTh,
      imageUrl: json['imageUrl'] as String? ?? '',
      shopId: shopId,
      shopName: shopNameEn ?? '',
      shopNameEn: shopNameEn,
      shopNameMm: shopNameMm,
      shopNameTh: shopNameTh,
      price: price,
      rating: rating,
      reviewCount: reviewCount,
      isFavorite: json['isFavorite'] == true,
      currency: json['currency'] as String? ?? '฿',
      originalPrice: originalPrice,
      displayPrice: json['displayPrice'] as String?,
      distanceKm: distanceKm,
      estimatedTime:
          json['estimatedTime']?.toString() ?? json['shopEstimatedTime']?.toString(),
      deliveryFee: _parseDeliveryFee(json),
      originalDeliveryFee: _parseOriginalDeliveryFee(json),
      isAvailable: json['isAvailable'] as bool? ?? true,
      publishStatus: json['publishStatus'] as String? ?? 'PUBLISHED',
    );
  }

  /// Mirrors backend `effectiveMenuItemPrice` when `price` is omitted.
  static double _effectivePrice(
    double? originalPrice,
    dynamic discountAmount,
    dynamic discountPercentage,
  ) {
    final base = originalPrice ?? 0;
    final amount = discountAmount is num ? discountAmount.toDouble() : 0;
    if (amount > 0) {
      final discounted = base - amount;
      return discounted > 0 ? discounted : base;
    }
    final pct = discountPercentage is num ? discountPercentage.toDouble() : 0;
    if (pct > 0) {
      return base * (1 - pct / 100);
    }
    return base;
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
  final String? mealType;

  TrendingSectionDto({
    required this.title,
    required this.description,
    required this.items,
    required this.totalCount,
    this.mealType,
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

  /// Parses `GET /api/user/search/trending-nearby` (menu items + meta + mealType).
  factory TrendingSectionDto.fromTrendingNearbyResponse(
    Map<String, dynamic> json,
  ) {
    final data = json['data'];
    final items = data is List
        ? data
            .whereType<Map<String, dynamic>>()
            .map(TrendingItemDto.fromJson)
            .toList()
        : <TrendingItemDto>[];
    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final total = (meta['total'] as num?)?.toInt() ?? items.length;

    return TrendingSectionDto(
      title: 'Trending Near By',
      description: '',
      items: items,
      totalCount: total,
      mealType: json['mealType']?.toString(),
    );
  }
}
