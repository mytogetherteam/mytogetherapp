import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/file_url_util.dart';
import 'cart_repository.dart';
import 'models/cart_dto.dart';

class CartItem {
  final String id;
  final int menuItemId;
  final String restaurantId;
  final String titleKey;
  final String? titleEn;
  final String? titleMm;
  final String? titleTh;
  final double price; // Using double for precision
  final double total; // Total for this item (price * quantity + options)
  final String imagePath;
  final String? imageUrl;
  final int quantity;
  final String? options;
  final List<int>? optionIds;
  final String? specialInstructions;
  final int? variantId;
  final String? variantNameKey;
  final String? variantNameEn;
  final String? variantNameMm;
  final String? variantNameTh;

  String get title => LocaleController.instance.localizedOr(
        titleKey,
        en: titleEn ?? titleKey,
        mm: titleMm,
        th: titleTh,
      );

  String? get variantName {
    if (variantNameKey == null &&
        variantNameEn == null &&
        variantNameMm == null &&
        variantNameTh == null) {
      return null;
    }
    final value = LocaleController.instance.localizedOr(
      variantNameKey ?? '',
      en: variantNameEn ?? variantNameKey,
      mm: variantNameMm,
      th: variantNameTh,
    );
    return value.isEmpty ? null : value;
  }

  CartItem({
    required this.id,
    required this.menuItemId,
    required this.restaurantId,
    required this.titleKey,
    this.titleEn,
    this.titleMm,
    this.titleTh,
    required this.price,
    required this.total,
    required this.imagePath,
    this.imageUrl,
    this.quantity = 1,
    this.options,
    this.optionIds,
    this.specialInstructions,
    this.variantId,
    this.variantNameKey,
    this.variantNameEn,
    this.variantNameMm,
    this.variantNameTh,
  });

  int get priceValue => price.round();
}

class CartStore {
  final int? shopId;
  final String nameKey;
  final String? nameEn;
  final String? nameMm;
  final String? nameTh;
  final List<CartItem> items;
  final double total;
  final String distance;
  final String time;
  final String? shopImageUrl;

  String get name => LocaleController.instance.localizedOr(
        nameKey,
        en: nameEn ?? nameKey,
        mm: nameMm,
        th: nameTh,
      );

  CartStore({
    this.shopId,
    required this.nameKey,
    this.nameEn,
    this.nameMm,
    this.nameTh,
    required this.items,
    this.total = 0,
    this.distance = '2 km',
    this.time = '20 Mins',
    this.shopImageUrl,
  });

  bool get isClosed => nameKey == 'Lotteria' || nameKey == 'Ice Berry'; // Mock data
}

class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  final List<CartStore> _stores = [];

  static const _cacheKey = 'cart_cache_json';
  static const _cacheTimestampKey = 'cart_cache_ts';
  static const _guestCartKey = 'guest_cart_v1';
  static const _cacheTtlMs = 5 * 60 * 1000; // 5 minutes

  int _guestLineIdSeq = 0;

  bool get _isGuest => !AuthService().isLoggedIn;

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
    if (_isGuest) {
      await _loadGuestCart();
      return;
    }

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

  int _indexForStore(String storeKey, {int? shopId}) {
    if (shopId != null) {
      final byId = _stores.indexWhere((s) => s.shopId == shopId);
      if (byId != -1) return byId;
    }
    return _stores.indexWhere(
      (s) => s.nameKey == storeKey || s.name == storeKey,
    );
  }

  CartStore _mapDtoToStore(CartDto cart) {
    final shopImage = FileUrlUtil.resolve(cart.shopImageUrl);
    return CartStore(
      shopId: cart.shopId,
      nameKey: cart.shopNameKey.isNotEmpty ? cart.shopNameKey : 'Unknown Store',
      nameEn: cart.shopNameEn,
      nameMm: cart.shopNameMm,
      nameTh: cart.shopNameTh,
      total: cart.total,
      shopImageUrl: shopImage.isEmpty ? null : shopImage,
      items: cart.items.map((item) {
        final image = FileUrlUtil.resolve(item.imageUrl);
        return CartItem(
        id: item.id.toString(),
        menuItemId: item.menuItemId,
        restaurantId: cart.shopId?.toString() ?? '0',
        titleKey: item.nameKey,
        titleEn: item.nameEn,
        titleMm: item.nameMm,
        titleTh: item.nameTh,
        price: item.price,
        total: item.total,
        imagePath: image,
        imageUrl: image.isEmpty ? null : image,
        quantity: item.quantity,
        options: item.optionNames?.join(', '),
        optionIds: item.optionIds,
        specialInstructions: item.specialInstructions,
        variantId: item.variantId,
        variantNameKey: item.variantNameKey,
        variantNameEn: item.variantNameEn,
        variantNameMm: item.variantNameMm,
        variantNameTh: item.variantNameTh,
      );
      }).toList(),
    );
  }

  Future<CartDto?> addMenuItem({
    required AddToCartRequest request,
    required double unitPrice,
    required String itemNameEn,
    String? itemNameMm,
    String? itemNameTh,
    required String shopNameEn,
    String? shopNameMm,
    String? shopNameTh,
    String? imageUrl,
    String? currency,
    String? variantNameEn,
    String? variantNameMm,
    String? variantNameTh,
    List<String>? optionNames,
  }) async {
    if (!_isGuest) {
      final dto = await CartRepository.instance.addToCart(request);
      updateCartFromDto(dto);
      await invalidateCache();
      try {
        final carts = await CartRepository.instance.getAllCarts();
        await _cacheCart(carts);
      } catch (_) {}
      return dto;
    }

    await _loadGuestCart();
    final shopId = request.shopId;
    if (shopId == null || shopId <= 0) {
      throw Exception('Invalid shop');
    }

    final optionIds = request.optionIds ?? const <int>[];
    final existing = findItemInCarts(
      request.menuItemId,
      variantId: request.variantId,
      optionIds: optionIds.isEmpty ? null : optionIds,
    );

    final carts = _stores.map(_storeToDto).toList();
    var cartIndex = carts.indexWhere((c) => c.shopId == shopId);
    if (cartIndex == -1) {
      carts.add(
        CartDto(
          shopId: shopId,
          shopName: shopNameEn,
          shopNameEn: shopNameEn,
          shopNameMm: shopNameMm,
          shopNameTh: shopNameTh,
          items: const [],
          subtotal: 0,
          deliveryFee: 0,
          total: 0,
          totalItems: 0,
          currency: currency,
        ),
      );
      cartIndex = carts.length - 1;
    }

    final cart = carts[cartIndex];
    final items = List<CartItemDto>.from(cart.items);

    if (existing != null) {
      final idx = items.indexWhere((i) => i.id.toString() == existing.id);
      if (idx != -1) {
        final old = items[idx];
        final qty = old.quantity + request.quantity;
        final lineTotal = unitPrice * qty;
        items[idx] = CartItemDto(
          id: old.id,
          menuItemId: old.menuItemId,
          name: old.nameKey,
          nameEn: old.nameEn,
          nameMm: old.nameMm,
          nameTh: old.nameTh,
          quantity: qty,
          price: unitPrice,
          total: lineTotal,
          imageUrl: old.imageUrl,
          variantName: old.variantNameKey,
          variantNameEn: old.variantNameEn,
          variantNameMm: old.variantNameMm,
          variantNameTh: old.variantNameTh,
          optionNames: old.optionNames,
          optionIds: old.optionIds,
          variantId: old.variantId,
          specialInstructions:
              request.specialInstructions ?? old.specialInstructions,
          currency: old.currency,
        );
      }
    } else {
      final lineId = _nextGuestLineId();
      final lineTotal = unitPrice * request.quantity;
      items.add(
        CartItemDto(
          id: lineId,
          menuItemId: request.menuItemId,
          name: itemNameEn,
          nameEn: itemNameEn,
          nameMm: itemNameMm,
          nameTh: itemNameTh,
          quantity: request.quantity,
          price: unitPrice,
          total: lineTotal,
          imageUrl: imageUrl,
          variantName: variantNameEn,
          variantNameEn: variantNameEn,
          variantNameMm: variantNameMm,
          variantNameTh: variantNameTh,
          optionNames: optionNames,
          optionIds: optionIds.isEmpty ? null : optionIds,
          variantId: request.variantId,
          specialInstructions: request.specialInstructions,
          currency: currency,
        ),
      );
    }

    final rebuilt = _rebuildCartDto(cart, items);
    if (cartIndex < carts.length) {
      carts[cartIndex] = rebuilt;
    }
    await _persistGuestCarts(carts);
    _updateFromCarts(carts);
    return rebuilt;
  }

  CartDto _rebuildCartDto(CartDto cart, List<CartItemDto> items) {
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.total);
    final totalItems = items.fold<int>(0, (sum, i) => sum + i.quantity);
    return CartDto(
      shopId: cart.shopId,
      shopName: cart.shopNameKey,
      shopNameEn: cart.shopNameEn,
      shopNameMm: cart.shopNameMm,
      shopNameTh: cart.shopNameTh,
      shopImageUrl: cart.shopImageUrl,
      items: items,
      subtotal: subtotal,
      deliveryFee: cart.deliveryFee,
      total: subtotal + cart.deliveryFee,
      totalItems: totalItems,
      currency: cart.currency,
    );
  }

  CartDto _storeToDto(CartStore store) {
    return CartDto(
      shopId: store.shopId,
      shopName: store.nameKey,
      shopNameEn: store.nameEn,
      shopNameMm: store.nameMm,
      shopNameTh: store.nameTh,
      shopImageUrl: store.shopImageUrl,
      items: store.items
          .map(
            (item) => CartItemDto(
              id: int.tryParse(item.id) ?? 0,
              menuItemId: item.menuItemId,
              name: item.titleKey,
              nameEn: item.titleEn,
              nameMm: item.titleMm,
              nameTh: item.titleTh,
              quantity: item.quantity,
              price: item.price,
              total: item.total,
              imageUrl: item.imageUrl ?? item.imagePath,
              variantName: item.variantNameKey,
              variantNameEn: item.variantNameEn,
              variantNameMm: item.variantNameMm,
              variantNameTh: item.variantNameTh,
              optionNames: item.options?.split(', '),
              optionIds: item.optionIds,
              variantId: item.variantId,
              specialInstructions: item.specialInstructions,
            ),
          )
          .toList(),
      subtotal: store.total,
      deliveryFee: 0,
      total: store.total,
      totalItems: store.items.fold<int>(0, (sum, i) => sum + i.quantity),
    );
  }

  Future<void> _loadGuestCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_guestCartKey);
      if (raw == null) {
        _stores.clear();
        notifyListeners();
        return;
      }
      final decoded = json.decode(raw) as List<dynamic>;
      final carts = decoded
          .map((e) => CartDto.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final cart in carts) {
        for (final item in cart.items) {
          if (item.id < _guestLineIdSeq) {
            _guestLineIdSeq = item.id;
          }
        }
      }
      _updateFromCarts(carts);
    } catch (_) {
      _stores.clear();
      notifyListeners();
    }
  }

  Future<void> _persistGuestCarts(List<CartDto> carts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(carts.map((c) => c.toJson()).toList());
    await prefs.setString(_guestCartKey, encoded);
  }

  int _nextGuestLineId() {
    _guestLineIdSeq -= 1;
    return _guestLineIdSeq;
  }

  Future<CartDto?> _updateGuestItemQuantity(
    String storeName,
    String itemId,
    int newQuantity, {
    String? specialInstructions,
    int? variantId,
    List<int>? optionIds,
  }) async {
    await _loadGuestCart();
    final carts = _stores.map(_storeToDto).toList();
    for (var c = 0; c < carts.length; c++) {
      final cart = carts[c];
      if (cart.shopNameKey != storeName && cart.shopName != storeName) {
        continue;
      }
      final items = List<CartItemDto>.from(cart.items);
      final idx = items.indexWhere((i) => i.id.toString() == itemId);
      if (idx == -1) continue;

      if (newQuantity <= 0) {
        items.removeAt(idx);
      } else {
        final old = items[idx];
        final unit = old.quantity > 0 ? old.total / old.quantity : old.price;
        items[idx] = CartItemDto(
          id: old.id,
          menuItemId: old.menuItemId,
          name: old.nameKey,
          nameEn: old.nameEn,
          nameMm: old.nameMm,
          nameTh: old.nameTh,
          quantity: newQuantity,
          price: unit,
          total: unit * newQuantity,
          imageUrl: old.imageUrl,
          variantName: old.variantNameKey,
          variantNameEn: old.variantNameEn,
          variantNameMm: old.variantNameMm,
          variantNameTh: old.variantNameTh,
          optionNames: old.optionNames,
          optionIds: optionIds ?? old.optionIds,
          variantId: variantId ?? old.variantId,
          specialInstructions: specialInstructions ?? old.specialInstructions,
          currency: old.currency,
        );
      }

      CartDto? result;
      if (items.isEmpty) {
        carts.removeAt(c);
        result = null;
      } else {
        result = _rebuildCartDto(cart, items);
        carts[c] = result;
      }
      await _persistGuestCarts(carts);
      _updateFromCarts(carts);
      return result;
    }
    return null;
  }

  Future<void> _clearGuestCart({int? shopId}) async {
    await _loadGuestCart();
    List<CartDto> carts;
    if (shopId != null) {
      carts = _stores
          .map(_storeToDto)
          .where((c) => c.shopId != shopId)
          .toList();
    } else {
      carts = [];
    }
    await _persistGuestCarts(carts);
    _updateFromCarts(carts);
  }

  /// Updates the local state from a single shop's CartDto
  void updateCartFromDto(CartDto dto) {
    final existingIndex = _indexForStore(dto.shopNameKey, shopId: dto.shopId);
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
    int index = _indexForStore(storeName);
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
    final storeIndex = _indexForStore(storeName);
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
               shopId: store.shopId,
               nameKey: store.nameKey,
               nameEn: store.nameEn,
               nameMm: store.nameMm,
               nameTh: store.nameTh,
               distance: store.distance,
               time: store.time,
               shopImageUrl: store.shopImageUrl,
               items: updatedItems,
               total: updatedItems.fold(0, (sum, item) => sum + item.total),
            );
          }
        } else {
          final updatedItems = List<CartItem>.from(store.items);
          final oldItem = updatedItems[itemIndex];
          updatedItems[itemIndex] = CartItem(
            id: oldItem.id,
            menuItemId: oldItem.menuItemId,
            restaurantId: oldItem.restaurantId,
            titleKey: oldItem.titleKey,
            titleEn: oldItem.titleEn,
            titleMm: oldItem.titleMm,
            titleTh: oldItem.titleTh,
            price: oldItem.price, 
            total: (oldItem.total / oldItem.quantity) * newQuantity, // Scale total with quantity
            imagePath: oldItem.imagePath,
            imageUrl: oldItem.imageUrl,
            quantity: newQuantity,
            options: options ?? oldItem.options, 
            optionIds: optionIds ?? oldItem.optionIds, 
            specialInstructions: specialInstructions ?? oldItem.specialInstructions, 
            variantId: variantId ?? oldItem.variantId, 
            variantNameKey: variantName ?? oldItem.variantNameKey,
            variantNameEn: variantName ?? oldItem.variantNameEn,
            variantNameMm: variantNameMm ?? oldItem.variantNameMm,
            variantNameTh: oldItem.variantNameTh,
          );
          _stores[storeIndex] = CartStore(
            shopId: store.shopId,
            nameKey: store.nameKey,
            nameEn: store.nameEn,
            nameMm: store.nameMm,
            nameTh: store.nameTh,
            distance: store.distance,
            time: store.time,
            shopImageUrl: store.shopImageUrl,
            items: updatedItems,
            total: updatedItems.fold(0, (sum, item) => sum + item.total),
          );
        }
        notifyListeners(); // Refresh UI instantly
      }
    }
    // ----------------------------

    if (_isGuest) {
      final result = await _updateGuestItemQuantity(
        storeName,
        itemId,
        newQuantity,
        specialInstructions: specialInstructions,
        variantId: variantId,
        optionIds: optionIds,
      );
      return result;
    }

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
        final deletedIndex = _indexForStore(storeName);
        if (deletedIndex != -1) _stores.removeAt(deletedIndex);
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
    int storeIndex = _indexForStore(storeName);
    if (storeIndex != -1) {
      for (var item in _stores[storeIndex].items) {
        total += item.total.round();
      }
    }
    return total;
  }

  Future<void> removeStore(String storeName) async {
    final storeIndex = _indexForStore(storeName);
    if (storeIndex == -1) return;

    if (_isGuest) {
      final shopId = _stores[storeIndex].shopId;
      if (shopId != null) {
        await _clearGuestCart(shopId: shopId);
      } else {
        final carts = _stores.map(_storeToDto).toList()
          ..removeWhere(
            (c) => c.shopNameKey == storeName || c.shopName == storeName,
          );
        await _persistGuestCarts(carts);
        _updateFromCarts(carts);
      }
      return;
    }

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
    if (_isGuest) {
      await _clearGuestCart();
      return;
    }
    await CartRepository.instance.clearCart();
    await invalidateCache();
    await syncWithApi();
  }

  /// Resets the cart when the session ends (logout, account deletion, token
  /// expiry). Clears the in-memory stores immediately so listeners (e.g. the
  /// cart FAB) update right away, drops the signed-in user's cached cart so it
  /// can't leak into the next session, then reloads the guest cart.
  Future<void> resetForSession() async {
    _stores.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (_) {}
    await _loadGuestCart();
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

  /// Helper to check if a specific menu item is in a specific store's cart
  CartItem? findItem(String storeName, int menuItemId) {
    final storeIndex = _indexForStore(storeName);
    if (storeIndex != -1) {
      for (var item in _stores[storeIndex].items) {
        if (item.menuItemId == menuItemId) return item;
      }
    }
    return null;
  }
}
