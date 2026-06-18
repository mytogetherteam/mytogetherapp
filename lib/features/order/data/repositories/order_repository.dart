import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../models/order_history_dto.dart';

/// Talks to the new backend's user-orders endpoint.
/// Backend route: `GET /api/user/orders` (UserOrdersController.findAll).
/// Response shape: `{ success, message, data: [...], meta: { page, size, total, ... } }`.
class OrderRepository {
  static final OrderRepository _instance = OrderRepository._internal();
  factory OrderRepository() => _instance;
  OrderRepository._internal();

  final ApiClient _apiClient = ApiClient();

  /// Fetches current and past orders grouped client-side. The new backend
  /// no longer ships a `/history-grouped` endpoint, so we pull the user's
  /// orders and bucket them by `ongoing` (derived from status).
  Future<OrderHistoryGroupedDto?> getGroupedOrders({int? shopId}) async {
    final all = await getOrderHistory(shopId: shopId);
    if (all.isEmpty) return null;

    final current = all.where((o) => o.ongoing).toList();
    final past = all.where((o) => !o.ongoing).toList();
    return OrderHistoryGroupedDto(currentOrders: current, pastOrders: past);
  }

  /// Fetches a flat list of order history for the current user.
  ///
  /// [statuses] is sent to the backend via `?status=` (comma-separated). The
  /// backend uses `ParseStringArrayPipe` and validates against `OrderStatus`.
  Future<List<OrderHistoryDto>> getOrderHistory({
    List<String>? statuses,
    int? shopId,
    int page = 1,
    int size = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'size': size,
      };
      if (statuses != null && statuses.isNotEmpty) {
        queryParams['status'] = statuses.join(',');
      }
      if (shopId != null) queryParams['shopId'] = shopId;

      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/orders',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data;
        // Envelope shape: { success, data: [...], meta }
        final rawData = body is Map ? body['data'] : body;
        final List<dynamic> list =
            rawData is List ? rawData : <dynamic>[];
        return list
            .map((e) => OrderHistoryDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Responds to a REVISED order by re-submitting a new item list.
  /// Backend: PATCH /api/user/orders/:id/items (UserOrdersController.respondRevise).
  /// Items not included are removed; totals are recomputed; status resets to
  /// PENDING. Each item: { menuItemId, quantity, variantId?,
  /// specialInstructions?, menuItemOptionId? }.
  ///
  /// The endpoint is now multipart-capable (it also accepts a `paymentImage`),
  /// so we send the items as a JSON-encoded `items` field which the backend
  /// parses back into the validated array.
  Future<bool> reviseOrderItems({
    required int orderId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.dio.patch(
      '${ApiClient.apiPrefix}/user/orders/$orderId/items',
      data: {'items': items},
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  /// Responds to a REVISED order by re-uploading a payment slip image.
  /// Backend: PATCH /api/user/orders/:id/items (UserOrdersController.respondRevise).
  /// When a `paymentImage` is attached, the backend re-processes the slip and
  /// moves the order to AWAITING_APPROVAL (same effect as the /payment route).
  Future<bool> revisePaymentImage({
    required int orderId,
    required File file,
  }) async {
    final extension = file.path.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final filename =
        'payment_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final formData = FormData.fromMap({
      'paymentImage': await MultipartFile.fromFile(
        file.path,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      ),
    });

    final response = await _apiClient.dio.patch(
      '${ApiClient.apiPrefix}/user/orders/$orderId/items',
      data: formData,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  /// Validates a pickup order without changing status.
  /// Backend: POST /api/user/orders/pickup/check
  Future<Map<String, dynamic>?> checkPickup({
    required String lastOrderNo,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/orders/pickup/check',
        data: {'lastOrderNo': lastOrderNo},
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          response.data is Map) {
        final body = Map<String, dynamic>.from(response.data as Map);
        if (body['success'] == true) {
          return body['data'] is Map
              ? Map<String, dynamic>.from(body['data'] as Map)
              : <String, dynamic>{};
        }
      }
    } catch (_) {}
    return null;
  }

  /// Confirms pickup, moving the order to PICKED_UP.
  /// Backend: POST /api/user/orders/pickup
  Future<Map<String, dynamic>?> confirmPickup({
    required String lastOrderNo,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/orders/pickup',
        data: {'lastOrderNo': lastOrderNo},
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          response.data is Map) {
        final body = Map<String, dynamic>.from(response.data as Map);
        if (body['success'] == true) {
          return body['data'] is Map
              ? Map<String, dynamic>.from(body['data'] as Map)
              : <String, dynamic>{};
        }
      }
    } catch (_) {}
    return null;
  }
}
