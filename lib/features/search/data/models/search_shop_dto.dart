import '../../../home/data/models/shop_dto.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';

class SearchMenuItemPreviewDto {
  final int id;
  final String name;
  final double price;
  final double? originalPrice;
  final String? imageUrl;
  final bool isFavorite;

  SearchMenuItemPreviewDto({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    this.isFavorite = false,
  });

  factory SearchMenuItemPreviewDto.fromJson(Map<String, dynamic> json) {
    return SearchMenuItemPreviewDto(
      id: json['id'] ?? 0,
      name: LocaleController.instance.localized(
        en: json['nameEn'] as String?,
        mm: json['nameMm'] as String?,
        th: json['nameTh'] as String?,
      ),
      price: (json['price'] ?? 0).toDouble(),
      originalPrice: json['originalPrice'] != null
          ? (json['originalPrice'] as num).toDouble()
          : null,
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']),
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

class SearchShopDto {
  final ShopListItemDto shop;
  final List<SearchMenuItemPreviewDto> menuItems;

  SearchShopDto({
    required this.shop,
    this.menuItems = const [],
  });

  factory SearchShopDto.fromJson(Map<String, dynamic> json) {
    return SearchShopDto(
      shop: ShopListItemDto.fromJson(json),
      menuItems: (json['menuItems'] as List? ?? [])
          .map((e) => SearchMenuItemPreviewDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SearchPageResult {
  final List<SearchShopDto> shops;
  final int currentPage;
  final int lastPage;
  final int total;

  SearchPageResult({
    required this.shops,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory SearchPageResult.fromJson(Map<String, dynamic> json) {
    final raw = json;
    final List<dynamic> dataList = raw['data'] is List
        ? raw['data'] as List
        : const [];

    final meta = raw['meta'] as Map<String, dynamic>? ?? {};
    final currentPage = meta['current_page'] ?? meta['page'] ?? 1;
    final lastPage = meta['last_page'] ?? 1;
    final total = meta['total'] ?? dataList.length;

    return SearchPageResult(
      shops: dataList
          .map((e) => SearchShopDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: currentPage is int
          ? currentPage
          : int.tryParse(currentPage.toString()) ?? 1,
      lastPage:
          lastPage is int ? lastPage : int.tryParse(lastPage.toString()) ?? 1,
      total: total is int ? total : int.tryParse(total.toString()) ?? 0,
    );
  }
}

/// Flat menu-item hit from `GET /api/user/menu-items/search`.
class MenuItemSearchResultDto {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;
  final int? shopId;
  final String? shopName;

  MenuItemSearchResultDto({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.shopId,
    this.shopName,
  });

  factory MenuItemSearchResultDto.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>?;
    return MenuItemSearchResultDto(
      id: json['id'] ?? 0,
      name: LocaleController.instance.localized(
        en: json['nameEn'] as String?,
        mm: json['nameMm'] as String?,
        th: json['nameTh'] as String?,
      ),
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']),
      shopId: shop?['id'] as int?,
      shopName: LocaleController.instance.localized(
        en: shop?['nameEn'] as String?,
        mm: shop?['nameMm'] as String?,
        th: shop?['nameTh'] as String?,
      ),
    );
  }
}
