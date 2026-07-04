/// Mirrors the `Wishlist` payloads returned by:
///   POST   /api/user/wishlist
///   GET    /api/user/wishlist/menu-items
///   GET    /api/user/wishlist/shop
///   DELETE /api/user/wishlist/:id
///
/// Backend: myshop_demo_api/src/modules/wishlist/wishlist.repository.ts
library;

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/image_utils.dart';

class WishlistItemDto {
  /// The wishlist row's primary key. Required when calling DELETE.
  final int id;
  final int? userId;
  final int? menuItemId;
  final int? shopId;
  final int? placeId;
  final String? createdAt;
  final WishlistMenuItemRef? menuItem;
  final WishlistShopRef? shop;
  final WishlistPlaceRef? place;

  WishlistItemDto({
    required this.id,
    this.userId,
    this.menuItemId,
    this.shopId,
    this.placeId,
    this.createdAt,
    this.menuItem,
    this.shop,
    this.place,
  });

  bool get isMenuItem => menuItemId != null || menuItem != null;
  bool get isShop => shopId != null || shop != null;
  bool get isPlace => placeId != null || place != null;

  factory WishlistItemDto.fromJson(Map<String, dynamic> json) {
    final menuMap = json['menuItem'];
    final shopMap = json['shop'];
    final placeMap = json['place'];
    return WishlistItemDto(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      menuItemId: (json['menuItemId'] as num?)?.toInt(),
      shopId: (json['shopId'] as num?)?.toInt(),
      placeId: (json['placeId'] as num?)?.toInt(),
      createdAt: json['createdAt']?.toString(),
      menuItem: menuMap is Map<String, dynamic>
          ? WishlistMenuItemRef.fromJson(menuMap)
          : null,
      shop: shopMap is Map<String, dynamic>
          ? WishlistShopRef.fromJson(shopMap)
          : null,
      place: placeMap is Map<String, dynamic>
          ? WishlistPlaceRef.fromJson(placeMap)
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
  final double? originalPrice;
  final double? discountAmount;
  final double? discountPercentage;
  final int? shopId;
  final bool isAvailable;

  /// The owning shop (included by the backend via `menuItem.shop`). Used to
  /// navigate to the restaurant detail page from a saved menu item.
  final WishlistShopRef? shop;

  WishlistMenuItemRef({
    required this.id,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.imageUrl,
    this.originalPrice,
    this.discountAmount,
    this.discountPercentage,
    this.shopId,
    this.isAvailable = true,
    this.shop,
  });

  String get displayName {
    final name = LocaleController.instance
        .localized(en: nameEn, mm: nameMm, th: nameTh);
    return name.isNotEmpty ? name : 'Item #$id';
  }

  /// Whether a fixed or percentage discount applies to this item.
  bool get hasDiscount {
    if (originalPrice == null) return false;
    return (discountAmount != null && discountAmount! > 0) ||
        (discountPercentage != null && discountPercentage! > 0);
  }

  /// Customer-facing selling price. Mirrors the backend's
  /// `effectiveMenuItemPrice` (originalPrice minus fixed/percentage discount).
  /// The backend no longer ships a flat `price` field on menu items.
  double? get effectivePrice {
    final base = originalPrice;
    if (base == null) return null;
    if (discountAmount != null && discountAmount! > 0) {
      final discounted = base - discountAmount!;
      // Bad legacy rows (discount >= price) fall back to the list price.
      return discounted > 0 ? discounted : base;
    }
    if (discountPercentage != null && discountPercentage! > 0) {
      final discounted = base * (1 - discountPercentage! / 100);
      return discounted < 0 ? 0 : discounted;
    }
    return base;
  }

  factory WishlistMenuItemRef.fromJson(Map<String, dynamic> json) {
    final shopMap = json['shop'];
    return WishlistMenuItemRef(
      id: (json['id'] as num).toInt(),
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      // Backend now sends `originalPrice` + discount fields (no flat `price`).
      // Keep `price` as a legacy fallback for older payloads.
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
      shopId: (json['shopId'] as num?)?.toInt(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      shop: shopMap is Map<String, dynamic>
          ? WishlistShopRef.fromJson(shopMap)
          : null,
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
  final String? primaryPhotoUrl;
  final List<String> imageUrls;
  final String? slug;
  final double? ratingAvg;
  final int? ratingCount;
  final bool isOpen;
  final bool isVerified;

  WishlistShopRef({
    required this.id,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.logoUrl,
    this.coverUrl,
    this.primaryPhotoUrl,
    this.imageUrls = const [],
    this.slug,
    this.ratingAvg,
    this.ratingCount,
    this.isOpen = true,
    this.isVerified = false,
  });

  String get displayName {
    final name = LocaleController.instance
        .localized(en: nameEn, mm: nameMm, th: nameTh);
    return name.isNotEmpty ? name : 'Shop #$id';
  }

  /// Banner image for cards (cover → gallery → logo → primary photo).
  String? get bannerImageUrl => ShopImageResolver.resolveBannerUrl(
        coverUrl: coverUrl,
        imageUrls: imageUrls,
        logoUrl: logoUrl,
        primaryPhotoUrl: primaryPhotoUrl,
      );

  factory WishlistShopRef.fromJson(Map<String, dynamic> json) {
    final imageUrls = ShopImageResolver.parseImageUrls(json);
    final primaryPhotoUrl = ImageUtils.cleanImageUrl(json['primaryPhotoUrl']) ??
        (imageUrls.isNotEmpty ? imageUrls.first : null);

    return WishlistShopRef(
      id: (json['id'] as num).toInt(),
      nameEn: json['nameEn']?.toString(),
      nameMm: json['nameMm']?.toString(),
      nameTh: json['nameTh']?.toString(),
      logoUrl: ImageUtils.cleanImageUrl(json['logoUrl']),
      coverUrl: ImageUtils.cleanImageUrl(json['coverUrl']),
      primaryPhotoUrl: primaryPhotoUrl,
      imageUrls: imageUrls,
      slug: json['slug']?.toString(),
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt(),
      isOpen: json['isOpen'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }
}

class WishlistPlaceRef {
  final int id;
  final String? titleEn;
  final String? titleMm;
  final String? titleTh;
  final String? coverUrl;
  final String? locationName;

  WishlistPlaceRef({
    required this.id,
    this.titleEn,
    this.titleMm,
    this.titleTh,
    this.coverUrl,
    this.locationName,
  });

  String get displayName {
    final name = LocaleController.instance.localized(
      en: titleEn,
      mm: titleMm,
      th: titleTh,
    );
    return name.isNotEmpty ? name : 'Place #$id';
  }

  factory WishlistPlaceRef.fromJson(Map<String, dynamic> json) {
    return WishlistPlaceRef(
      id: (json['id'] as num).toInt(),
      titleEn: json['titleEn']?.toString(),
      titleMm: json['titleMm']?.toString(),
      titleTh: json['titleTh']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      locationName: json['locationName']?.toString(),
    );
  }
}
