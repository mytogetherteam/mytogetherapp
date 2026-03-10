import 'package:flutter/material.dart';
import 'cart_repository.dart';
import 'models/cart_dto.dart';

class CartItem {
  final String id;
  final int menuItemId;
  final String restaurantId;
  final String title;
  final String? nameMm;
  final double price; // Using double for precision
  final String imagePath;
  final String? imageUrl;
  final int quantity;
  final String? options;
  final List<int>? optionIds;
  final String? specialInstructions;
  final int? variantId;
  final String? variantName;
  final String? variantNameMm;

  CartItem({
    required this.id,
    required this.menuItemId,
    required this.restaurantId,
    required this.title,
    required this.price,
    required this.imagePath,
    this.nameMm,
    this.imageUrl,
    this.quantity = 1,
    this.options,
    this.optionIds,
    this.specialInstructions,
    this.variantId,
    this.variantName,
    this.variantNameMm,
  });

  int get priceValue => price.round();
}

class CartStore {
  final String name;
  final List<CartItem> items;
  final String distance;
  final String time;

  CartStore({
    required this.name,
    required this.items,
    this.distance = '2 km',
    this.time = '20 Mins',
  });

  bool get isClosed => name == 'Lotteria' || name == 'Ice Berry'; // Mock data
}

class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  final List<CartStore> _stores = [];

  List<CartStore> get stores => List.unmodifiable(_stores);

  Future<void> syncWithApi() async {
    try {
      final carts = await CartRepository.instance.getAllCarts();
      _updateFromCarts(carts);
    } catch (e) {
      debugPrint('Error syncing cart with API: $e');
    }
  }

  void _updateFromCarts(List<CartDto> carts) {
    _stores.clear();
    for (var cart in carts) {
      _stores.add(_mapDtoToStore(cart));
    }
    notifyListeners();
  }

  CartStore _mapDtoToStore(CartDto cart) {
    return CartStore(
      name: cart.shopName ?? 'Unknown Store',
      items: cart.items.map((item) => CartItem(
        id: item.id.toString(),
        menuItemId: item.menuItemId,
        restaurantId: cart.shopId?.toString() ?? '0',
        title: item.name,
        nameMm: item.nameMm,
        price: item.price,
        imagePath: item.imageUrl ?? '',
        imageUrl: item.imageUrl,
        quantity: item.quantity,
        options: item.optionNames?.join(', '),
        optionIds: item.optionIds,
        specialInstructions: item.specialInstructions,
        variantId: item.variantId,
        variantName: item.variantName,
        variantNameMm: item.variantNameMm,
      )).toList(),
    );
  }

  /// Updates the local state from a single shop's CartDto
  void updateCartFromDto(CartDto dto) {
    final existingIndex = _stores.indexWhere((s) => s.name == dto.shopName);
    if (existingIndex != -1) {
      _stores[existingIndex] = _mapDtoToStore(dto);
    } else {
      _stores.add(_mapDtoToStore(dto));
    }
    notifyListeners();
  }

  int get totalItemCount {
    int count = 0;
    for (var store in _stores) {
      for (var item in store.items) {
        count += item.quantity;
      }
    }
    return count;
  }

  int getStoreItemCount(String storeName) {
    int count = 0;
    int index = _stores.indexWhere((s) => s.name == storeName);
    if (index != -1) {
      for (var item in _stores[index].items) {
        count += item.quantity;
      }
    }
    return count;
  }

  /// Deprecated: Local adding is removed in favor of direct API calls.
  /// This now just triggers a sync to ensure UI is fresh.
  void addItem({
    required String id,
    required String restaurantId,
    required String storeName,
    required String itemTitle,
    required double itemPrice,
    required String itemImagePath,
    String? nameMm,
    String? imageUrl,
    int quantity = 1,
    String? options,
    String? specialInstructions,
    int? variantId,
    String? variantName,
    String? variantNameMm,
  }) {
    syncWithApi();
  }

  Future<CartDto?> updateItemQuantity(
    String storeName, 
    String itemId, 
    int newQuantity, {
    String? options, 
    String? specialInstructions, 
    int? variantId,
    List<int>? optionIds,
  }) async {
    final cartItemId = int.tryParse(itemId);
    if (cartItemId == null) return null;

    try {
      CartDto? result;
      if (newQuantity <= 0) {
        result = await CartRepository.instance.removeCartItem(cartItemId);
      } else {
        result = await CartRepository.instance.updateCartItem(cartItemId, UpdateCartItemRequest(
          quantity: newQuantity,
          specialInstructions: specialInstructions,
          variantId: variantId,
          optionIds: optionIds,
        ));
      }
      
      if (result != null) {
        updateCartFromDto(result);
      }
      
      return result;
    } catch (e) {
      debugPrint('Error updating cart item: $e');
      return null;
    }
  }

  int getStoreTotal(String storeName) {
    int total = 0;
    int storeIndex = _stores.indexWhere((s) => s.name == storeName);
    if (storeIndex != -1) {
      for (var item in _stores[storeIndex].items) {
        total += (item.priceValue * item.quantity);
      }
    }
    return total;
  }

  Future<void> removeStore(String storeName) async {
    final storeIndex = _stores.indexWhere((s) => s.name == storeName);
    if (storeIndex == -1) return;

    final itemsToRemove = List<CartItem>.from(_stores[storeIndex].items);
    
    try {
      // Remove each item in this store from the backend
      for (var item in itemsToRemove) {
        final cartItemId = int.tryParse(item.id);
        if (cartItemId != null) {
          await CartRepository.instance.removeCartItem(cartItemId);
        }
      }
      
      // Sync with API to get fresh state
      await syncWithApi();
    } catch (e) {
      debugPrint('Error removing store items: $e');
      // Still sync just in case some were removed
      await syncWithApi();
    }
  }

  Future<void> clearCart() async {
    await CartRepository.instance.clearCart();
    await syncWithApi();
  }

  /// Finds a cart item matching the given criteria across all stores.
  CartItem? findItemInCarts(int menuItemId, {int? variantId, List<int>? optionIds}) {
    for (var store in _stores) {
      for (var item in store.items) {
        if (item.menuItemId == menuItemId) {
          // If variantId is provided, it must match
          if (variantId != null && item.variantId != variantId) continue;
          
          // If optionIds are provided, they must match exactly
          if (optionIds != null) {
            final itemOptionIds = item.optionIds ?? [];
            if (itemOptionIds.length != optionIds.length) continue;
            
            final setA = Set.from(itemOptionIds);
            final setB = Set.from(optionIds);
            if (!setA.containsAll(setB)) continue;
          }
          
          return item;
        }
      }
    }
    return null;
  }
}
