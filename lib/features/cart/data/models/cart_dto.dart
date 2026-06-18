import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/file_url_util.dart';
import '../../../../core/utils/image_utils.dart';

/// Request body for POST /api/mobile/cart/items
class AddToCartRequest {
  final int menuItemId;
  final int quantity;
  final int? shopId;
  final List<int>? optionIds;
  final int? variantId;
  final String? specialInstructions;

  const AddToCartRequest({
    required this.menuItemId,
    required this.quantity,
    this.shopId,
    this.optionIds,
    this.variantId,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'menuItemId': menuItemId,
      'quantity': quantity,
      'optionIds': optionIds ?? [],
    };
    
    if (shopId != null && shopId! > 0) {
      map['shopId'] = shopId;
    }
    
    if (variantId != null && variantId! > 0) {
      map['variantId'] = variantId;
    }
    
    if (specialInstructions != null && specialInstructions!.trim().isNotEmpty) {
      map['specialInstructions'] = specialInstructions;
    }
    
    return map;
  }
}

/// Request body for PUT /api/mobile/cart/items/{itemId}
class UpdateCartItemRequest {
  final int quantity;
  final String? specialInstructions;
  final int? variantId;
  final List<int>? optionIds;

  const UpdateCartItemRequest({
    required this.quantity,
    this.specialInstructions,
    this.variantId,
    this.optionIds,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'quantity': quantity};
    if (specialInstructions != null) {
      map['specialInstructions'] = specialInstructions;
    }
    if (variantId != null) {
      map['variantId'] = variantId;
    }
    if (optionIds != null) {
      map['optionIds'] = optionIds;
    }
    return map;
  }
}

/// Represents a single item in the cart response
class CartItemDto {
  final int id;
  final int menuItemId;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final int quantity;
  final double price;
  final double total;
  final String? displayPrice;
  final String? displayTotal;
  final String? imageUrl;
  final String? _variantName;
  final String? variantNameEn;
  final String? variantNameMm;
  final String? variantNameTh;
  final List<String>? optionNames;
  final List<int>? optionIds;
  final int? variantId;
  final String? specialInstructions;
  final String? currency;
  final List<SelectedOptionDto>? selectedOptions;

  String get name => LocaleController.instance.localizedOr(
        _name,
        en: nameEn ?? _name,
        mm: nameMm,
        th: nameTh,
      );

  String get nameKey => nameEn ?? _name;

  String? get variantName {
    if (_variantName == null &&
        variantNameEn == null &&
        variantNameMm == null &&
        variantNameTh == null) {
      return null;
    }
    final value = LocaleController.instance.localizedOr(
      _variantName ?? '',
      en: variantNameEn ?? _variantName,
      mm: variantNameMm,
      th: variantNameTh,
    );
    return value.isEmpty ? null : value;
  }

  String? get variantNameKey => variantNameEn ?? _variantName;

  const CartItemDto({
    required this.id,
    required this.menuItemId,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.quantity,
    required this.price,
    required this.total,
    this.displayPrice,
    this.displayTotal,
    this.imageUrl,
    String? variantName,
    this.variantNameEn,
    this.variantNameMm,
    this.variantNameTh,
    this.optionNames,
    this.optionIds,
    this.variantId,
    this.specialInstructions,
    this.currency,
    this.selectedOptions,
  })  : _name = name,
        _variantName = variantName;

  factory CartItemDto.fromJson(Map<String, dynamic> json) {
    final selectedOptions = (json['selectedOptions'] as List<dynamic>?)
        ?.map((e) => SelectedOptionDto.fromJson(e as Map<String, dynamic>))
        .toList();

    // Handle nested optionGroups in cart response if present
    final optionGroups = json['optionGroups'] as List<dynamic>?;
    List<int>? groupOptionIds;
    List<String>? groupOptionNames;
    
    if (optionGroups != null) {
      groupOptionIds = [];
      groupOptionNames = [];
      for (var group in optionGroups) {
        if (group is Map) {
          final options = group['options'] as List<dynamic>?;
          if (options != null) {
            for (var opt in options) {
              if (opt is Map) {
                final id = int.tryParse(opt['id']?.toString() ?? '');
                if (id != null) groupOptionIds.add(id);
                
                final displayName = opt['nameEn']?.toString() ??
                    opt['name']?.toString() ??
                    opt['nameMm']?.toString() ??
                    opt['nameTh']?.toString() ??
                    '';
                if (displayName.isNotEmpty) groupOptionNames.add(displayName);
              }
            }
          }
        }
      }
    }

    return CartItemDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      menuItemId: int.tryParse(json['menuItemId']?.toString() ?? '') ?? 0,
      name: (json['name'] as String? ?? json['nameEn'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
      displayTotal: json['displayTotal'] as String?,
      imageUrl: json['imageUrl'] as String?,
      variantName:
          json['variantName'] as String? ?? json['variantNameEn'] as String?,
      variantNameEn:
          json['variantNameEn'] as String? ?? json['variantName'] as String?,
      variantNameMm: json['variantNameMm'] as String?,
      variantNameTh: json['variantNameTh'] as String?,
      optionNames: (json['optionNames'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? groupOptionNames ?? selectedOptions?.map((o) => o.name).toList(),
      optionIds: (json['optionIds'] as List<dynamic>?)
          ?.map((e) => int.tryParse(e.toString()) ?? 0)
          .toList() ?? groupOptionIds ?? selectedOptions?.map((o) => o.id).toList(),
      variantId: int.tryParse(json['variantId']?.toString() ?? ''),
      specialInstructions: json['specialInstructions'] as String?,
      currency: json['currency'] as String?,
      selectedOptions: selectedOptions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'menuItemId': menuItemId,
    'name': _name,
    'nameEn': nameEn,
    'nameMm': nameMm,
    'nameTh': nameTh,
    'quantity': quantity,
    'price': price,
    'total': total,
    'displayPrice': displayPrice,
    'displayTotal': displayTotal,
    'imageUrl': imageUrl,
    'variantName': _variantName,
    'variantNameEn': variantNameEn,
    'variantNameMm': variantNameMm,
    'variantNameTh': variantNameTh,
    'optionNames': optionNames,
    'optionIds': optionIds,
    'variantId': variantId,
    'specialInstructions': specialInstructions,
    'currency': currency,
    'selectedOptions': selectedOptions?.map((e) => e.toJson()).toList(),
  };
}

class SelectedOptionDto {
  final int id;
  final String _name;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final double price;
  final String? displayPrice;

  String get name => LocaleController.instance.localizedOr(
        _name,
        en: nameEn ?? _name,
        mm: nameMm,
        th: nameTh,
      );

  SelectedOptionDto({
    required this.id,
    required String name,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.price,
    this.displayPrice,
  }) : _name = name;

  factory SelectedOptionDto.fromJson(Map<String, dynamic> json) {
    return SelectedOptionDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['nameEn'] as String? ?? json['name'] as String?) ?? '',
      nameEn: json['nameEn'] as String? ?? json['name'] as String?,
      nameMm: json['nameMm'] as String?,
      nameTh: json['nameTh'] as String?,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': _name,
    'nameEn': nameEn,
    'nameMm': nameMm,
    'nameTh': nameTh,
    'price': price,
    'displayPrice': displayPrice,
  };
}

/// Represents the full cart response
class CartDto {
  final int? shopId;
  final String? _shopName;
  final String? shopNameEn;
  final String? shopNameMm;
  final String? shopNameTh;
  final String? shopImageUrl;
  final List<CartItemDto> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final int totalItems;
  final String? currency;

  String? get shopName {
    final value = LocaleController.instance.localizedOr(
      _shopName ?? '',
      en: shopNameEn ?? _shopName,
      mm: shopNameMm,
      th: shopNameTh,
    );
    return value.isEmpty ? null : value;
  }

  /// Stable English/default shop name used for cart store lookups.
  String get shopNameKey => shopNameEn ?? _shopName ?? '';

  const CartDto({
    this.shopId,
    String? shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopNameTh,
    this.shopImageUrl,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.totalItems,
    this.currency,
  }) : _shopName = shopName;

  factory CartDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final itemsJson = data['items'] as List<dynamic>? ?? [];
    final shopNameEn = data['shopNameEn'] as String? ??
        data['shopName'] as String? ??
        data['name'] as String? ??
        data['restaurantName'] as String?;
    final shopMap = data['shop'] is Map
        ? Map<String, dynamic>.from(data['shop'] as Map)
        : null;

    return CartDto(
      shopId: data['shopId'] as int?,
      shopName: shopNameEn,
      shopNameEn: shopNameEn,
      shopNameMm: data['shopNameMm'] as String?,
      shopNameTh: data['shopNameTh'] as String?,
      shopImageUrl: _resolveShopImageUrl(data, shopMap),
      items: itemsJson
          .map((e) => CartItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: double.tryParse(data['subtotal']?.toString() ?? '') ?? 0.0,
      deliveryFee: double.tryParse(data['deliveryFee']?.toString() ?? '') ?? 0.0,
      total: double.tryParse(data['total']?.toString() ?? '') ?? 0.0,
      totalItems: data['totalItems'] as int? ?? 0,
      currency: data['currency'] as String?,
    );
  }

  /// Total number of individual items (sum of quantities)
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  static String? _resolveShopImageUrl(
    Map<String, dynamic> data,
    Map<String, dynamic>? shopMap,
  ) {
    if (shopMap != null) {
      final fromShop = ShopImageResolver.resolveShopAvatarFromJson(shopMap);
      if (fromShop != null && fromShop.isNotEmpty) {
        return FileUrlUtil.resolve(fromShop);
      }
    }

    for (final raw in [
      data['shopLogo'],
      data['logoUrl'],
      data['shopLogoUrl'],
      data['shopImageUrl'],
    ]) {
      final resolved = FileUrlUtil.resolve(raw?.toString());
      if (resolved.isNotEmpty) return resolved;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'shopId': shopId,
    'shopName': _shopName,
    'shopNameEn': shopNameEn,
    'shopNameMm': shopNameMm,
    'shopNameTh': shopNameTh,
    'shopImageUrl': shopImageUrl,
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'total': total,
    'totalItems': totalItems,
    'currency': currency,
  };
}
