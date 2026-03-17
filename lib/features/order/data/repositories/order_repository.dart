import 'package:mytogetherapp/core/network/api_client.dart';
import '../models/order_history_dto.dart';

class OrderRepository {
  static final OrderRepository _instance = OrderRepository._internal();
  factory OrderRepository() => _instance;
  OrderRepository._internal();

  final ApiClient _apiClient = ApiClient();

  /// Fetches current and past orders grouped.
  Future<OrderHistoryGroupedDto?> getGroupedOrders() async {
    try {
      final response = await _apiClient.dio.get('${ApiClient.apiPrefix}/orders/history-grouped');
      if (response.statusCode == 200 && response.data != null) {
        return OrderHistoryGroupedDto.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Fetches a flat list of order history.
  Future<List<OrderHistoryDto>> getOrderHistory({List<String>? statuses}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (statuses != null && statuses.isNotEmpty) {
        queryParams['statuses'] = statuses.join(',');
      }

      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/orders/history',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List<dynamic>? ?? [];
        return data.map((e) => OrderHistoryDto.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }
}
