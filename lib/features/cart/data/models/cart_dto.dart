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
  });

  factory CartItemDto.fromJson(Map<String, dynamic> json) {
    return CartItemDto(
      id: json['id'] as int? ?? 0,
      menuItemId: json['menuItemId'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      nameMm: json['nameMm'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      displayPrice: json['displayPrice'] as String?,
      displayTotal: json['displayTotal'] as String?,
      imageUrl: json['imageUrl'] as String?,
      variantName: json['variantName'] as String?,
      variantNameMm: json['variantNameMm'] as String?,
      optionNames: (json['optionNames'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      optionIds: (json['optionIds'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      variantId: json['variantId'] as int?,
      specialInstructions: json['specialInstructions'] as String?,
      currency: json['currency'] as String?,
    );
  }
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
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      totalItems: data['totalItems'] as int? ?? 0,
      currency: data['currency'] as String?,
    );
  }

  /// Total number of individual items (sum of quantities)
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
}
