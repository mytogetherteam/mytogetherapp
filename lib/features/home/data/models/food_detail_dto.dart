import '../../../../core/utils/image_utils.dart';
import '../../../../core/localization/locale_controller.dart';
import 'shop_dto.dart';

class ApiResponseFoodDetailDto {
  final int statusCode;
  final String? message;
  final FoodDetailDto? data;

  ApiResponseFoodDetailDto({
    required this.statusCode,
    this.message,
    this.data,
  });

  factory ApiResponseFoodDetailDto.fromJson(Map<String, dynamic> json) {
    return ApiResponseFoodDetailDto(
      statusCode: json['statusCode'] ?? 0,
      message: json['message'],
      data: json['data'] != null ? FoodDetailDto.fromJson(json['data']) : null,
    );
  }
}

class FoodDetailDto {
  final int id;
  final int? shopId;
  final String? _shopName;
  final String? shopNameEn;
  final String? shopNameMm;
  final String? shopNameTh;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final String? description;
  final double price;
  final double? originalPrice;
  final String currency;
  final String imageUrl;
  final List<String> photoUrls;
  final List<MenuItemVariantDto> variants;
  final List<MenuItemOptionGroupDto> optionGroups;
  final bool isFavorite;
  final bool isAvailable;

  final CuisineTypeDto? cuisineType;

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  String? get shopName {
    if (shopNameEn != null || shopNameMm != null || shopNameTh != null) {
      final v = LocaleController.instance
          .localized(en: shopNameEn, mm: shopNameMm, th: shopNameTh);
      if (v.isNotEmpty) return v;
    }
    return _shopName;
  }

  FoodDetailDto({
    required this.id,
    this.shopId,
    String? shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopNameTh,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.description,
    required this.price,
    this.originalPrice,
    this.currency = '฿',
    required this.imageUrl,
    this.photoUrls = const [],
    this.variants = const [],
    this.optionGroups = const [],
    required this.isFavorite,
    this.isAvailable = true,
    this.cuisineType,
  })  : _name = name,
        _shopName = shopName;

  factory FoodDetailDto.fromJson(Map<String, dynamic> json) {
    // The user menu-item detail endpoint nests shop info under `shop` and uses
    // `addOns` for option groups; older/public payloads used flat `shopId` /
    // `shopName*` and `optionGroups`. Read both so either shape works.
    final shop = json['shop'] is Map
        ? Map<String, dynamic>.from(json['shop'] as Map)
        : null;

    return FoodDetailDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      shopId: json['shopId'] ?? shop?['id'],
      shopName: (json['shopName'] as String? ??
          json['shopNameEn'] as String? ??
          shop?['nameEn'] as String?),
      shopNameEn: json['shopNameEn'] as String? ??
          json['shopName'] as String? ??
          shop?['nameEn'] as String?,
      shopNameMm: json['shopNameMm'] as String? ?? shop?['nameMm'] as String?,
      shopNameTh: json['shopNameTh'] as String? ?? shop?['nameTh'] as String?,
      name: (json['name'] as String? ?? json['nameEn'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      description: json['description'],
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      originalPrice: double.tryParse(json['originalPrice']?.toString() ?? '') ?? 0.0,
      currency: json['currency'] as String? ?? '฿',
      imageUrl: ImageUtils.cleanImageUrl(json['imageUrl']) ?? '',
      cuisineType: json['cuisineType'] != null ? CuisineTypeDto.fromJson(json['cuisineType']) : null,
      photoUrls: (json['photos'] as List? ?? [])
          .map((e) {
            if (e is Map) return ImageUtils.cleanImageUrl(e['url']?.toString());
            return ImageUtils.cleanImageUrl(e.toString());
          })
          .whereType<String>()
          .toList(),
      variants: _sortedVariantsFromJson(json),
      optionGroups: _optionGroupsFromJson(json),
      isFavorite: json['isFavorite'] ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }
}

List<MenuItemVariantDto> _sortedVariantsFromJson(Map<String, dynamic> json) {
  final apiGroups = (json['variantGroups'] as List? ?? const [])
      .whereType<Map>()
      .map((g) => Map<String, dynamic>.from(g))
      .toList();

  final groupMetaById = <int, Map<String, dynamic>>{
    for (final group in apiGroups)
      if (int.tryParse(group['id']?.toString() ?? '') != null)
        int.parse(group['id'].toString()): group,
  };

  final variants = (json['variants'] as List? ?? const [])
      .where((e) => e != null)
      .map((e) => MenuItemVariantDto.fromJson(Map<String, dynamic>.from(e as Map)))
      .where((v) => v.isAvailable)
      .map((variant) {
        final groupId = variant.variantGroupId;
        final group = groupId != null ? groupMetaById[groupId] : null;
        if (group == null) return variant;
        return MenuItemVariantDto(
          id: variant.id,
          name: variant.name,
          nameEn: variant.nameEn,
          nameMm: variant.nameMm,
          nameTh: variant.nameTh,
          price: variant.price,
          displayPrice: variant.displayPrice,
          isAvailable: variant.isAvailable,
          displayOrder: variant.displayOrder,
          variantGroupId: groupId,
          variantGroupDisplayOrder: variant.variantGroupDisplayOrder ??
              group['displayOrder'] as int?,
          variantGroupNameEn:
              variant.variantGroupNameEn ?? group['nameEn'] as String?,
          variantGroupNameMm:
              variant.variantGroupNameMm ?? group['nameMm'] as String?,
          variantGroupNameTh:
              variant.variantGroupNameTh ?? group['nameTh'] as String?,
        );
      })
      .toList();

  variants.sort((a, b) {
    final groupOrder =
        (a.variantGroupDisplayOrder ?? 0).compareTo(b.variantGroupDisplayOrder ?? 0);
    if (groupOrder != 0) return groupOrder;
    return (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0);
  });

  return variants;
}

List<MenuItemOptionGroupDto> _optionGroupsFromJson(Map<String, dynamic> json) {
  final nestedRaw =
      (json['optionGroups'] as List?) ?? (json['addOns'] as List?) ?? const [];
  final flatRaw = json['options'] as List? ?? const [];

  final groupsById = <int, MenuItemOptionGroupDto>{};
  final groupOrder = <int>[];

  for (final raw in nestedRaw) {
    if (raw is! Map) continue;
    final group = MenuItemOptionGroupDto.fromJson(Map<String, dynamic>.from(raw));
    if (!group.isAvailable || group.options.isEmpty) continue;
    groupsById[group.id] = group;
    groupOrder.add(group.id);
  }

  final nestedOptionIds = <int>{
    for (final group in groupsById.values)
      for (final option in group.options)
        if (option.id > 0) option.id,
  };

  final ungrouped = <MenuItemOptionDto>[];

  for (final raw in flatRaw) {
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final option = MenuItemOptionDto.fromJson(map);
    if (option.id > 0 && nestedOptionIds.contains(option.id)) continue;

    final embeddedGroupRaw = map['optionGroup'] ?? map['group'];
    final embeddedGroup = embeddedGroupRaw is Map
        ? Map<String, dynamic>.from(embeddedGroupRaw)
        : null;
    final embeddedDeleted = embeddedGroup?['deletedAt'] != null;
    final groupId = int.tryParse(map['optionGroupId']?.toString() ?? '') ??
        int.tryParse(embeddedGroup?['id']?.toString() ?? '');

    if (groupId != null &&
        groupId > 0 &&
        !embeddedDeleted &&
        groupsById.containsKey(groupId)) {
      final group = groupsById[groupId]!;
      if (group.options.any((o) => o.id == option.id)) continue;
      groupsById[groupId] = group.copyWith(
        options: [...group.options, option]
          ..sort(
            (a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0),
          ),
      );
      continue;
    }

    ungrouped.add(option);
  }

  if (ungrouped.isNotEmpty) {
    ungrouped.sort(
      (a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0),
    );
    groupsById[0] = MenuItemOptionGroupDto(
      id: 0,
      name: '',
      options: ungrouped,
    );
    groupOrder.add(0);
  }

  final merged = groupOrder.map((id) => groupsById[id]!).toList();
  merged.sort(
    (a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0),
  );
  return merged;
}

class MenuItemVariantDto {
  final int id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final double price;
  final String? displayPrice;
  final bool isAvailable;
  final int? displayOrder;
  final int? variantGroupId;
  final int? variantGroupDisplayOrder;
  final String? variantGroupNameEn;
  final String? variantGroupNameMm;
  final String? variantGroupNameTh;

  String? get variantGroupName => LocaleController.instance.localized(
        en: variantGroupNameEn,
        mm: variantGroupNameMm,
        th: variantGroupNameTh,
      );

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  MenuItemVariantDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.price,
    this.displayPrice,
    this.isAvailable = true,
    this.displayOrder,
    this.variantGroupId,
    this.variantGroupDisplayOrder,
    this.variantGroupNameEn,
    this.variantGroupNameMm,
    this.variantGroupNameTh,
  }) : _name = name;

  factory MenuItemVariantDto.fromJson(Map<String, dynamic> json) {
    final embeddedGroup = json['variantGroup'] is Map
        ? Map<String, dynamic>.from(json['variantGroup'] as Map)
        : null;

    return MenuItemVariantDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
      isAvailable: json['isAvailable'] ?? true,
      displayOrder: json['displayOrder'] as int?,
      variantGroupId: int.tryParse(json['variantGroupId']?.toString() ?? '') ??
          int.tryParse(embeddedGroup?['id']?.toString() ?? ''),
      variantGroupDisplayOrder: json['variantGroupDisplayOrder'] as int? ??
          embeddedGroup?['displayOrder'] as int?,
      variantGroupNameEn: json['variantGroupNameEn'] as String? ??
          embeddedGroup?['nameEn'] as String?,
      variantGroupNameMm: json['variantGroupNameMm'] as String? ??
          embeddedGroup?['nameMm'] as String?,
      variantGroupNameTh: json['variantGroupNameTh'] as String? ??
          embeddedGroup?['nameTh'] as String?,
    );
  }
}

class MenuItemOptionGroupDto {
  final int id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final int? displayOrder;
  final bool isAvailable;
  final List<MenuItemOptionDto> options;

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  MenuItemOptionGroupDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    this.displayOrder,
    this.isAvailable = true,
    required this.options,
  }) : _name = name;

  MenuItemOptionGroupDto copyWith({
    int? id,
    String? name,
    String? nameEn,
    String? nameMm,
    String? nameTh,
    int? displayOrder,
    bool? isAvailable,
    List<MenuItemOptionDto>? options,
  }) {
    return MenuItemOptionGroupDto(
      id: id ?? this.id,
      name: name ?? _name,
      nameEn: nameEn ?? this.nameEn,
      nameMm: nameMm ?? this.nameMm,
      nameTh: nameTh ?? this.nameTh,
      displayOrder: displayOrder ?? this.displayOrder,
      isAvailable: isAvailable ?? this.isAvailable,
      options: options ?? this.options,
    );
  }

  factory MenuItemOptionGroupDto.fromJson(Map<String, dynamic> json) {
    final isAvailable = json['isAvailable'] as bool? ?? true;
    final options = (json['options'] as List? ?? [])
        .where((e) => e != null)
        .map((e) => MenuItemOptionDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((o) => o.isAvailable)
        .toList()
      ..sort(
        (a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0),
      );
    return MenuItemOptionGroupDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      displayOrder: json['displayOrder'] as int?,
      isAvailable: isAvailable,
      options: options,
    );
  }
}

class MenuItemOptionDto {
  final int id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final double price;
  final String? displayPrice;
  final int? displayOrder;
  final bool isAvailable;

  String get name => LocaleController.instance
      .localizedOr(_name, en: nameEn, mm: nameMm, th: nameTh);

  MenuItemOptionDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.price,
    this.displayPrice,
    this.displayOrder,
    this.isAvailable = true,
  }) : _name = name;

  factory MenuItemOptionDto.fromJson(Map<String, dynamic> json) {
    return MenuItemOptionDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
      displayOrder: json['displayOrder'] as int?,
      isAvailable: json['isAvailable'] as bool? ?? json['deletedAt'] == null,
    );
  }
}
