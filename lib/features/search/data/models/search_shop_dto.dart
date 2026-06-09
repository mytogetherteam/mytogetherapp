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
    final shopData = json['shop'] is Map<String, dynamic>
        ? json['shop'] as Map<String, dynamic>
        : json;
    return SearchShopDto(
      shop: ShopListItemDto.fromJson(shopData),
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
    List<dynamic> dataList = const [];
    
    if (raw['data'] is List) {
      dataList = raw['data'] as List;
    } else if (raw['data'] is Map) {
      final mapData = raw['data'] as Map<String, dynamic>;
      if (mapData['content'] is List) {
        dataList = mapData['content'] as List;
      } else if (mapData['data'] is List) {
        dataList = mapData['data'] as List;
      } else if (mapData['shops'] is List) {
        dataList = mapData['shops'] as List;
      }
    } else if (raw['content'] is List) {
      dataList = raw['content'] as List;
    } else if (raw['shops'] is List) {
      dataList = raw['shops'] as List;
    }

    final meta = raw['meta'] as Map<String, dynamic>? ?? {};
    int currentPage = meta['current_page'] ?? meta['page'] ?? 1;
    int lastPage = meta['last_page'] ?? 1;
    int total = meta['total'] ?? dataList.length;

    if (raw['data'] is Map<String, dynamic>) {
      final mapData = raw['data'] as Map<String, dynamic>;
      if (mapData.containsKey('number')) {
        currentPage = (mapData['number'] as int? ?? 0) + 1;
        lastPage = (mapData['totalPages'] as int? ?? 1);
        total = mapData['totalElements'] as int? ?? dataList.length;
      }
    } else if (raw.containsKey('number')) {
        currentPage = (raw['number'] as int? ?? 0) + 1;
        lastPage = (raw['totalPages'] as int? ?? 1);
        total = raw['totalElements'] as int? ?? dataList.length;
    }

    return SearchPageResult(
      shops: dataList
          .map((e) => SearchShopDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
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
