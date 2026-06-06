import 'shop_feed_item_dto.dart';

/// Flattens a backend `formatMenuItem` payload (which carries a nested
/// `shop: { id, nameEn, ... }`) into the flat shape [ShopFeedItemDto] expects
/// (`shopId`, `shopNameEn`). Shared by collections and the "for you" feed.
Map<String, dynamic> flattenMenuItemForFeed(Map<String, dynamic> json) {
  final shop = json['shop'];
  final flat = Map<String, dynamic>.from(json);
  if (shop is Map) {
    flat['shopId'] ??= shop['id'];
    flat['shopNameEn'] ??= shop['nameEn'];
    flat['shopNameMm'] ??= shop['nameMm'];
    flat['shopNameTh'] ??= shop['nameTh'];
  }
  return flat;
}

/// A curated collection of menu items from
/// `GET /api/user/collections` and `GET /api/user/collections/:id`.
class CollectionDto {
  final int id;
  final String name;
  final String? description;
  final int itemCount;
  final List<ShopFeedItemDto> items;

  CollectionDto({
    required this.id,
    required this.name,
    this.description,
    required this.itemCount,
    this.items = const [],
  });

  factory CollectionDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map((e) => ShopFeedItemDto.fromJson(flattenMenuItemForFeed(e)))
            .toList()
        : <ShopFeedItemDto>[];

    return CollectionDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Collection',
      description: json['description']?.toString(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }
}
