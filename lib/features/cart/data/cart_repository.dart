import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'models/cart_dto.dart';

/// Repository for all Shopping Cart API operations.
/// Endpoints: POST /api/mobile/cart/items, GET /api/mobile/cart,
/// PUT /api/mobile/cart/items/{id}, DELETE /api/mobile/cart/items/{id},
/// DELETE /api/mobile/cart, GET /api/mobile/cart/list
class CartRepository {
  static final CartRepository instance = CartRepository._internal();
  CartRepository._internal();

  final ApiClient _apiClient = ApiClient();

  /// Adds an item to the cart.
  /// Returns the updated [CartDto].
  Future<CartDto> addToCart(AddToCartRequest request) async {
    final payload = request.toJson();
    debugPrint('CART_PAYLOAD: $payload');
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/cart/items',
        data: payload,
      );
      return CartDto.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'add to cart');
    } catch (e) {
      throw Exception('Failed to add to cart: $e');
    }
  }

  /// Gets the current cart contents.
  Future<CartDto?> getCart({int? shopId, double? lat, double? lon}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (shopId != null) queryParams['shopId'] = shopId;
      if (lat != null) queryParams['lat'] = lat;
      if (lon != null) queryParams['lon'] = lon;

      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/cart',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data == null) return null;
        return CartDto.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Updates the quantity of a cart item by its [cartItemId].
  Future<CartDto> updateCartItem(int cartItemId, UpdateCartItemRequest request) async {
    final response = await _apiClient.dio.put(
      '${ApiClient.apiPrefix}/cart/items/$cartItemId',
      data: request.toJson(),
    );
    _assertSuccess(response.statusCode, 'update cart item');
    return CartDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Removes a single item from the cart by its [cartItemId].
  Future<CartDto> removeCartItem(int cartItemId) async {
    final response = await _apiClient.dio.delete(
      '${ApiClient.apiPrefix}/cart/items/$cartItemId',
    );
    _assertSuccess(response.statusCode, 'remove cart item');
    return CartDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Clears the entire cart.
  Future<void> clearCart() async {
    await _apiClient.dio.delete('${ApiClient.apiPrefix}/cart');
  }

  /// Returns a list of all active carts.
  Future<List<CartDto>> getAllCarts() async {
    try {
      final response = await _apiClient.dio.get('${ApiClient.apiPrefix}/cart/list');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        debugPrint('GET_CART_LIST_RESPONSE: $data');
        if (data is List) {
          return data
              .map((e) => CartDto.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Exception _handleDioError(DioException e, String operation) {
    if (e.response != null) {
      final data = e.response!.data;
      final statusCode = e.response!.statusCode;
      if (data is Map) {
        if (data.containsKey('message')) return Exception(data['message']);
        if (data.containsKey('error')) return Exception(data['error']);
        if (data.containsKey('code')) return Exception('${data['code']}: ${data['path']}');
      }
      return Exception('Server Error ($statusCode): ${e.response!.data}');
    }
    return Exception('Network Error: ${e.message}');
  }

  void _assertSuccess(int? statusCode, String operation) {
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw Exception('Failed to $operation: HTTP $statusCode');
    }
  }
}
