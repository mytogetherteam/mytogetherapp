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

  /// Re-submits a REVISED order with a new item list.
  /// Backend: PATCH /api/user/orders/:id/items (UserOrdersController.updateItems).
  /// Items not included are removed; totals are recomputed; status resets to
  /// PENDING. Each item: { menuItemId, quantity, variantId?,
  /// specialInstructions?, menuItemOptionId? }.
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
}
