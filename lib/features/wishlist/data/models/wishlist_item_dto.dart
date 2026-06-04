/// Mirrors the `Wishlist` payloads returned by:
///   POST   /api/user/wishlist
///   GET    /api/user/wishlist/menu-items
///   GET    /api/user/wishlist/shop
///   DELETE /api/user/wishlist/:id
///
/// Backend: myshop_demo_api/src/modules/wishlist/wishlist.repository.ts
class WishlistItemDto {
  /// The wishlist row's primary key. Required when calling DELETE.
  final int id;
  final int? userId;
  final int? menuItemId;
  final int? shopId;
  final String? createdAt;
  final WishlistMenuItemRef? menuItem;
  final WishlistShopRef? shop;

  WishlistItemDto({
    required this.id,
    this.userId,
    this.menuItemId,
    this.shopId,
    this.createdAt,
    this.menuItem,
    this.shop,
  });

  bool get isMenuItem => menuItemId != null || menuItem != null;
  bool get isShop => shopId != null || shop != null;

  factory WishlistItemDto.fromJson(Map<String, dynamic> json) {
    final menuMap = json['menuItem'];
    final shopMap = json['shop'];
    return WishlistItemDto(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      menuItemId: (json['menuItemId'] as num?)?.toInt(),
      shopId: (json['shopId'] as num?)?.toInt(),
      createdAt: json['createdAt']?.toString(),
      menuItem: menuMap is Map<String, dynamic>
          ? WishlistMenuItemRef.fromJson(menuMap)
          : null,
      shop: shopMap is Map<String, dynamic>
          ? WishlistShopRef.fromJson(shopMap)
          : null,
    );
  }
}

class WishlistMenuItemRef {
  final int id;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? imageUrl;
  final double? price;
  final double? originalPrice;
  final int? shopId;
  final bool isAvailable;

  WishlistMenuItemRef({
    required this.id,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.imageUrl,
    this.price,
    this.originalPrice,
    this.shopId,
    this.isAvailable = true,
  });

  String get displayName =>
      nameEn ?? nameMm ?? nameTh ?? 'Item #$id';

  factory WishlistMenuItemRef.fromJson(Map<String, dynamic> json) {
    return WishlistMenuItemRef(
      id: (json['id'] as num).toInt(),
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      price: (json['price'] as num?)?.toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      shopId: (json['shopId'] as num?)?.toInt(),
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }
}

class WishlistShopRef {
  final int id;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? logoUrl;
  final String? coverUrl;
  final String? slug;
  final double? ratingAvg;
  final int? ratingCount;
  final bool isOpen;

  WishlistShopRef({
    required this.id,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.logoUrl,
    this.coverUrl,
    this.slug,
    this.ratingAvg,
    this.ratingCount,
    this.isOpen = true,
  });

  String get displayName => nameEn ?? nameMm ?? nameTh ?? 'Shop #$id';

  factory WishlistShopRef.fromJson(Map<String, dynamic> json) {
    return WishlistShopRef(
      id: (json['id'] as num).toInt(),
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      slug: json['slug']?.toString(),
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt(),
      isOpen: json['isOpen'] as bool? ?? true,
    );
  }
}
