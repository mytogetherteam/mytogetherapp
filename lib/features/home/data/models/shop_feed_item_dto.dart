import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';
import 'trending_item_dto.dart';

/// A single food item returned by any of the 5 shop feed endpoints
/// (right-now, for-you, hot-deals, trending, popular-dishes).
class ShopFeedItemDto {
  final int id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? imageUrl;
  final double price;
  final double? originalPrice;
  final double rating;
  final int reviewCount;
  final int shopId;
  final String _shopName;
  final String? shopNameEn;
  final String? shopNameMm;
  final String? shopNameTh;
  final bool isFavorite;
  final String currency;
  final String? displayPrice;
  final double? distanceKm;
  final String? _estimatedTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  // Real-time status fields (from API, updated by WebSocket)
  final bool isAvailable;
  final String publishStatus;
  // Menu category this item belongs to (used to group a shop's menu into
  // sections on the restaurant detail page). Null for feeds that don't carry it.
  final int? categoryId;
  final String? categoryName;

  /// Resolved live against the active language so a language switch updates
  /// already-loaded items without a refetch.
  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  String get shopName => LocaleController.instance
      .localizedOr(_shopName, en: shopNameEn, mm: shopNameMm, th: shopNameTh);

  String? get estimatedTime {
    if (distanceKm != null && distanceKm! > 0) {
      int minTime = (distanceKm! * 2.0).round();
      if (minTime < 1) minTime = 1;
      final int maxTime = minTime + 5;
      return '$minTime-$maxTime min';
    }
    return _estimatedTime;
  }

  ShopFeedItemDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.imageUrl,
    required this.price,
    this.originalPrice,
    required this.rating,
    required this.reviewCount,
    required this.shopId,
    required String shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopNameTh,
    required this.isFavorite,
    this.currency = '฿',
    this.displayPrice,
    this.distanceKm,
    String? estimatedTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    this.isAvailable = true,
    this.publishStatus = 'PUBLISHED',
    this.categoryId,
    this.categoryName,
  })  : _name = name,
        _shopName = shopName,
        _estimatedTime = estimatedTime;

  factory ShopFeedItemDto.fromJson(Map<String, dynamic> json) {
    return ShopFeedItemDto(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']),
      price: _parsePrice(json['price']),
      originalPrice: json['originalPrice'] != null ? _parsePrice(json['originalPrice']) : null,
      rating: _parsePrice(json['rating']),
      reviewCount: (json['reviewCount'] ?? json['ratingCount']) as int? ?? 0,
      shopId: int.tryParse(json['shopId'].toString()) ?? 0,
      shopName: (json['shopNameEn'] as String? ?? json['shopName'] as String?) ?? '',
      shopNameEn: json['shopNameEn'] as String? ?? json['shopName'] as String?,
      shopNameMm: json['shopNameMm'] as String?,
      shopNameTh: json['shopNameTh'] as String?,
      isFavorite: json['isFavorite'] ?? false,
      currency: json['currency'] as String? ?? '฿',
      displayPrice: json['displayPrice'] as String?,
      distanceKm: json['distanceKm'] != null 
          ? double.tryParse(json['distanceKm'].toString()) 
          : (json['shopDistanceKm'] != null ? double.tryParse(json['shopDistanceKm'].toString()) : null),
      estimatedTime: json['estimatedTime']?.toString() ?? json['shopEstimatedTime']?.toString(),
      deliveryFee: _parseDeliveryFee(json),
      originalDeliveryFee: _parseOriginalDeliveryFee(json),
      isAvailable: json['isAvailable'] as bool? ?? true,
      publishStatus: json['publishStatus'] as String? ?? 'PUBLISHED',
      categoryId: (json['menuCategoryId'] ?? json['categoryId']) != null
          ? int.tryParse((json['menuCategoryId'] ?? json['categoryId']).toString())
          : null,
      categoryName: (json['menuCategoryName'] ?? json['categoryName']) as String?,
    );
  }

  static String? _parseDeliveryFee(Map<String, dynamic> json) {
    if (json['displayBaseDeliveryFee'] != null) return json['displayBaseDeliveryFee'].toString();
    if (json['displayDeliveryFee'] != null) return json['displayDeliveryFee'].toString();
    // Discount carousel (`GET /api/user/menu-items/discount`) returns a numeric
    // `deliveryFee` rather than a pre-formatted display string.
    if (json['deliveryFee'] != null) return json['deliveryFee'].toString();
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

  /// Builds a feed card from `GET /api/user/search/trending-nearby` items.
  factory ShopFeedItemDto.fromTrendingItem(TrendingItemDto item) {
    return ShopFeedItemDto(
      id: item.id,
      name: item.name,
      nameEn: item.nameEn,
      nameMm: item.nameMm,
      nameTh: item.nameTh,
      imageUrl: item.imageUrl.isNotEmpty ? item.imageUrl : null,
      price: item.price,
      originalPrice: item.originalPrice,
      rating: item.rating,
      reviewCount: item.reviewCount,
      shopId: item.shopId,
      shopName: item.shopName,
      shopNameEn: item.shopNameEn,
      shopNameMm: item.shopNameMm,
      shopNameTh: item.shopNameTh,
      isFavorite: item.isFavorite,
      currency: item.currency,
      displayPrice: item.displayPrice,
      distanceKm: item.distanceKm,
      estimatedTime: item.estimatedTime,
      deliveryFee: item.deliveryFee,
      originalDeliveryFee: item.originalDeliveryFee,
      isAvailable: item.isAvailable,
      publishStatus: item.publishStatus,
    );
  }
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

/// Response of the home discount carousel
/// (`GET /api/user/menu-items/discount`). Backs the
/// "Together — Up to X% Off" strip on the home page.
///
/// Shape: `{ data: { sectionTitle, maxDiscountPercentage, items: [...] } }`.
/// Items are already flattened (shopId/shopName at the top level), so they
/// parse directly via [ShopFeedItemDto.fromJson].
class DiscountDealsDto {
  /// Server-built title, e.g. "MyTogether 50% Off" (uses the requested
  /// percentage). The UI usually renders its own styled header instead.
  final String sectionTitle;

  /// The largest discount percentage among the returned items. Use this for a
  /// dynamic "Up to X% Off" headline.
  final int maxDiscountPercentage;

  final List<ShopFeedItemDto> items;

  DiscountDealsDto({
    required this.sectionTitle,
    required this.maxDiscountPercentage,
    required this.items,
  });

  bool get isEmpty => items.isEmpty;

  factory DiscountDealsDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map((e) => ShopFeedItemDto.fromJson(e))
            .toList()
        : <ShopFeedItemDto>[];
    return DiscountDealsDto(
      sectionTitle: data['sectionTitle']?.toString() ?? '',
      maxDiscountPercentage:
          (data['maxDiscountPercentage'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }
}

class ApiResponseSliceShopFeedItemDto {
  final bool success;
  final String message;
  final SliceShopFeedItemDto data;

  ApiResponseSliceShopFeedItemDto({
    required this.success,
    required this.message,
    required this.data,
  });

  factory ApiResponseSliceShopFeedItemDto.fromJson(Map<String, dynamic> json) {
    return ApiResponseSliceShopFeedItemDto(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: SliceShopFeedItemDto.fromJson(json['data'] ?? {}),
    );
  }
}

class SliceShopFeedItemDto {
  final List<ShopFeedItemDto> content;
  final bool first;
  final bool last;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;

  SliceShopFeedItemDto({
    required this.content,
    required this.first,
    required this.last,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory SliceShopFeedItemDto.fromJson(Map<String, dynamic> json) {
    return SliceShopFeedItemDto(
      content: (json['content'] as List? ?? [])
          .map((e) => ShopFeedItemDto.fromJson(e))
          .toList(),
      first: json['first'] ?? false,
      last: json['last'] ?? false,
      number: json['number'] ?? 0,
      size: json['size'] ?? 0,
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
