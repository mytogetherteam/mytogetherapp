import 'package:dio/dio.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../models/order_review_dto.dart';

/// Result of attempting to create an order review.
///
/// Mirrors the relevant `BadRequestException` / `ConflictException` /
/// `ForbiddenException` / `NotFoundException` cases thrown by the backend's
/// [`UserOrderReviewService.create`](myshop_demo_api/src/modules/order-review/user/user-order-review.service.ts)
/// so the UI can show the right copy.
class OrderReviewSubmitResult {
  final bool success;
  final OrderReviewDto? review;
  final String? errorMessage;
  final OrderReviewErrorCode? errorCode;

  const OrderReviewSubmitResult._({
    required this.success,
    this.review,
    this.errorMessage,
    this.errorCode,
  });

  factory OrderReviewSubmitResult.ok(OrderReviewDto review) =>
      OrderReviewSubmitResult._(success: true, review: review);

  factory OrderReviewSubmitResult.failure(
    String message,
    OrderReviewErrorCode code,
  ) => OrderReviewSubmitResult._(
        success: false,
        errorMessage: message,
        errorCode: code,
      );
}

enum OrderReviewErrorCode {
  alreadyReviewed,
  notDelivered,
  notOwner,
  notFound,
  network,
  unknown,
}

/// Talks to the new backend's user order-review endpoints. Backend:
///   POST /api/user/order-reviews                          → create
///   GET  /api/user/order-reviews                          → list mine
///   GET  /api/user/order-reviews/by-order/:orderId        → my review for one order
///   GET  /api/user/order-reviews/:id                      → one review by id
class OrderReviewRepository {
  static final OrderReviewRepository instance = OrderReviewRepository._();
  OrderReviewRepository._();

  final ApiClient _apiClient = ApiClient();

  Future<OrderReviewSubmitResult> create({
    required int orderId,
    required double rating,
    String? comment,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiClient.apiPrefix}/user/order-reviews',
        data: {
          'orderId': orderId,
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );

      final data = _unwrapData(response.data);
      if (data is Map<String, dynamic>) {
        return OrderReviewSubmitResult.ok(OrderReviewDto.fromJson(data));
      }
      return OrderReviewSubmitResult.failure(
        'Review submitted but response was malformed.',
        OrderReviewErrorCode.unknown,
      );
    } on DioException catch (e) {
      return _mapDioError(e);
    } catch (_) {
      return OrderReviewSubmitResult.failure(
        'Something went wrong. Please try again.',
        OrderReviewErrorCode.unknown,
      );
    }
  }

  /// Fetches the current user's review for a single order, or null if it
  /// hasn't been reviewed yet (backend returns 404 in that case).
  Future<OrderReviewDto?> getReviewForOrder(int orderId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/order-reviews/by-order/$orderId',
      );
      final data = _unwrapData(response.data);
      if (data is Map<String, dynamic>) {
        return OrderReviewDto.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Fetches a single order review by its id.
  /// Backend: GET /api/user/order-reviews/:id. Returns null on 404.
  Future<OrderReviewDto?> getById(int id) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/order-reviews/$id',
      );
      final data = _unwrapData(response.data);
      if (data is Map<String, dynamic>) {
        return OrderReviewDto.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<OrderReviewDto>> getMyReviews({int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiClient.apiPrefix}/user/order-reviews',
        queryParameters: {'page': page, 'size': size},
      );
      final body = response.data;
      final List<dynamic> list = body is Map
          ? (body['data'] as List<dynamic>? ?? const [])
          : (body is List ? body : const []);
      return list
          .map((e) => OrderReviewDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  dynamic _unwrapData(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'];
      return body;
    }
    return body;
  }

  OrderReviewSubmitResult _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final serverMessage = body is Map<String, dynamic>
        ? (body['message']?.toString() ?? body['error']?.toString())
        : null;

    if (status == null) {
      return OrderReviewSubmitResult.failure(
        'No internet connection. Please try again.',
        OrderReviewErrorCode.network,
      );
    }
    if (status == 409) {
      return OrderReviewSubmitResult.failure(
        serverMessage ?? 'You have already reviewed this order.',
        OrderReviewErrorCode.alreadyReviewed,
      );
    }
    if (status == 400) {
      return OrderReviewSubmitResult.failure(
        serverMessage ?? 'You can only review delivered orders.',
        OrderReviewErrorCode.notDelivered,
      );
    }
    if (status == 403) {
      return OrderReviewSubmitResult.failure(
        serverMessage ?? 'You are not allowed to review this order.',
        OrderReviewErrorCode.notOwner,
      );
    }
    if (status == 404) {
      return OrderReviewSubmitResult.failure(
        serverMessage ?? 'Order not found.',
        OrderReviewErrorCode.notFound,
      );
    }
    return OrderReviewSubmitResult.failure(
      serverMessage ?? 'Something went wrong. Please try again.',
      OrderReviewErrorCode.unknown,
    );
  }
}
