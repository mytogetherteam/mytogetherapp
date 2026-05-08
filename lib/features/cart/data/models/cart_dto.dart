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
  final String name;
  final String? nameMm;
  final int quantity;
  final double price;
  final double total;
  final String? displayPrice;
  final String? displayTotal;
  final String? imageUrl;
  final String? variantName;
  final String? variantNameMm;
  final List<String>? optionNames;
  final List<int>? optionIds;
  final int? variantId;
  final String? specialInstructions;
  final String? currency;
  final List<SelectedOptionDto>? selectedOptions;

  const CartItemDto({
    required this.id,
    required this.menuItemId,
    required this.name,
    this.nameMm,
    required this.quantity,
    required this.price,
    required this.total,
    this.displayPrice,
    this.displayTotal,
    this.imageUrl,
    this.variantName,
    this.variantNameMm,
    this.optionNames,
    this.optionIds,
    this.variantId,
    this.specialInstructions,
    this.currency,
    this.selectedOptions,
  });

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
                
                final enName = opt['nameEn']?.toString() ?? opt['name']?.toString();
                final mmName = opt['nameMm']?.toString();
                final displayName = (enName != null && enName.trim().isNotEmpty) ? enName : (mmName ?? '');
                if (displayName.isNotEmpty) groupOptionNames.add(displayName);
              }
            }
          }
        }
      }
    }

    final enName = (json['name'] as String? ?? json['nameEn'] as String? ?? '').trim();
    final mmName = (json['nameMm'] as String? ?? '').trim();

    return CartItemDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      menuItemId: int.tryParse(json['menuItemId']?.toString() ?? '') ?? 0,
      name: enName.isNotEmpty ? enName : mmName,
      nameMm: json['nameMm'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
      displayTotal: json['displayTotal'] as String?,
      imageUrl: json['imageUrl'] as String?,
      variantName: json['variantName'] as String?,
      variantNameMm: json['variantNameMm'] as String?,
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
    'name': name,
    'nameMm': nameMm,
    'quantity': quantity,
    'price': price,
    'total': total,
    'displayPrice': displayPrice,
    'displayTotal': displayTotal,
    'imageUrl': imageUrl,
    'variantName': variantName,
    'variantNameMm': variantNameMm,
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
  final String name;
  final String? nameEn;
  final String? nameMm;
  final double price;
  final String? displayPrice;

  SelectedOptionDto({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameMm,
    required this.price,
    this.displayPrice,
  });

  factory SelectedOptionDto.fromJson(Map<String, dynamic> json) {
    final enName = json['nameEn'] as String? ?? json['name'] as String?;
    final mmName = json['nameMm'] as String?;
    return SelectedOptionDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (enName != null && enName.trim().isNotEmpty) ? enName : (mmName ?? ''),
      nameEn: json['nameEn'],
      nameMm: json['nameMm'],
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameEn': nameEn,
    'nameMm': nameMm,
    'price': price,
    'displayPrice': displayPrice,
  };
}

/// Represents the full cart response
class CartDto {
  final int? shopId;
  final String? shopName;
  final String? shopNameEn;
  final String? shopNameMm;
  final String? shopImageUrl;
  final List<CartItemDto> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final int totalItems;
  final String? currency;

  const CartDto({
    this.shopId,
    this.shopName,
    this.shopNameEn,
    this.shopNameMm,
    this.shopImageUrl,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.totalItems,
    this.currency,
  });

  factory CartDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final itemsJson = data['items'] as List<dynamic>? ?? [];
    final shopName = data['shopNameEn'] as String? ?? 
                     data['shopName'] as String? ?? 
                     data['shopNameMm'] as String? ?? 
                     data['name'] as String? ?? 
                     data['restaurantName'] as String?;

    return CartDto(
      shopId: data['shopId'] as int?,
      shopName: shopName,
      shopNameEn: data['shopNameEn'] as String?,
      shopNameMm: data['shopNameMm'] as String?,
      shopImageUrl: data['shopImageUrl'] as String? ?? data['imageUrl'] as String?,
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

  Map<String, dynamic> toJson() => {
    'shopId': shopId,
    'shopName': shopName,
    'shopNameEn': shopNameEn,
    'shopNameMm': shopNameMm,
    'shopImageUrl': shopImageUrl,
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'total': total,
    'totalItems': totalItems,
    'currency': currency,
  };
}
