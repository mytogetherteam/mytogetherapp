import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const _cacheKey = 'cart_cache_json';
  static const _cacheTimestampKey = 'cart_cache_ts';
  static const _cacheTtlMs = 5 * 60 * 1000; // 5 minutes

  List<CartStore> get stores => List.unmodifiable(_stores);

  /// Returns cached cart stores if the cache is fresh (< 5 min).
  /// Returns null if cache is stale or missing.
  Future<bool> _loadCachedCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_cacheTimestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - ts > _cacheTtlMs) return false; // stale

      final raw = prefs.getString(_cacheKey);
      if (raw == null) return false;

      final List<dynamic> decoded = json.decode(raw);
      final carts = decoded.map((e) => CartDto.fromJson(e as Map<String, dynamic>)).toList();
      _updateFromCarts(carts);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cacheCart(List<CartDto> carts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(carts.map((c) => c.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheTimestampKey);
    } catch (_) {}
  }

  Future<void> syncWithApi() async {
    // If cache is fresh, skip the API call entirely
    final hitCache = await _loadCachedCart();
    if (hitCache) return;

    try {
      final carts = await CartRepository.instance.getAllCarts();
      _updateFromCarts(carts);
      await _cacheCart(carts);
    } catch (e) {
      // Ignore sync errors
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
  }) async {
    await invalidateCache();
    await syncWithApi();
  }

  Future<CartDto?> updateItemQuantity(
    String storeName, 
    String itemId, 
    int newQuantity, {
    String? options, 
    String? specialInstructions, 
    int? variantId,
    String? variantName,
    String? variantNameMm,
    List<int>? optionIds,
  }) async {
    final cartItemId = int.tryParse(itemId);
    if (cartItemId == null) return null;

    // --- Optimistic UI Update ---
    final storeIndex = _stores.indexWhere((s) => s.name == storeName);
    if (storeIndex != -1) {
      final store = _stores[storeIndex];
      final itemIndex = store.items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        if (newQuantity <= 0) {
          final updatedItems = List<CartItem>.from(store.items)..removeAt(itemIndex);
          if (updatedItems.isEmpty) {
            _stores.removeAt(storeIndex);
          } else {
            _stores[storeIndex] = CartStore(
               name: store.name,
               distance: store.distance,
               time: store.time,
               items: updatedItems,
            );
          }
        } else {
          final updatedItems = List<CartItem>.from(store.items);
          final oldItem = updatedItems[itemIndex];
          updatedItems[itemIndex] = CartItem(
            id: oldItem.id,
            menuItemId: oldItem.menuItemId,
            restaurantId: oldItem.restaurantId,
            title: oldItem.title,
            price: oldItem.price, // Technically price could change based on variants/options, but the API sync will fix this in ~500ms
            imagePath: oldItem.imagePath,
            nameMm: oldItem.nameMm,
            imageUrl: oldItem.imageUrl,
            quantity: newQuantity,
            options: options ?? oldItem.options, // Use new options if provided
            optionIds: optionIds ?? oldItem.optionIds, // Use new optionIds if provided
            specialInstructions: specialInstructions ?? oldItem.specialInstructions, // Use new instructions if provided
            variantId: variantId ?? oldItem.variantId, // Use new variantId if provided
            variantName: variantName ?? oldItem.variantName, // Use new variantName if provided
            variantNameMm: variantNameMm ?? oldItem.variantNameMm, // Use new variantNameMm if provided
          );
          _stores[storeIndex] = CartStore(
            name: store.name,
            distance: store.distance,
            time: store.time,
            items: updatedItems,
          );
        }
        notifyListeners(); // Refresh UI instantly
      }
    }
    // ----------------------------


    try {
      CartDto? result;
      bool wasDeleted = false;
      if (newQuantity <= 0) {
        result = await CartRepository.instance.removeCartItem(cartItemId);
        wasDeleted = true;
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
        await invalidateCache();
      } else if (wasDeleted) {
        // API returned null on delete = success, cart is perfectly empty!
        _stores.removeWhere((s) => s.name == storeName);
        notifyListeners();
        await invalidateCache();
      }
      
      return result;
    } catch (e) {
      // If an update fails, force a sync to ensure local state matches server
      await syncWithApi();
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

      await invalidateCache();
      // Sync with API to get fresh state
      await syncWithApi();
    } catch (e) {
      // Still sync just in case some were removed
      await invalidateCache();
      await syncWithApi();
    }
  }

  Future<void> clearCart() async {
    await CartRepository.instance.clearCart();
    await invalidateCache();
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
