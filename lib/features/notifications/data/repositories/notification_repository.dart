import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

/// User order notifications on the NestJS backend:
///   GET    /api/user/notifications
///   GET    /api/user/notifications/unread-count
///   PUT    /api/user/notifications/:id/read
///   PUT    /api/user/notifications/read-all
///   DELETE /api/user/notifications/:id
class NotificationRepository {
  static final NotificationRepository _instance =
      NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  final Dio _dio = ApiClient().dio;

  /// Reactive unread count for real-time UI updates
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<List<NotificationModel>> getNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/user/notifications',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    if (response.statusCode != 200 || response.data == null) {
      return [];
    }

    final raw = response.data;
    final dynamic payload = raw is Map ? raw['data'] : raw;
    final List<dynamic> items = _extractItems(payload);

    return items
        .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(
        '${ApiClient.apiPrefix}/user/notifications/unread-count',
      );
      if (response.statusCode == 200 && response.data != null) {
        final count = _extractUnreadCount(response.data);
        unreadCount.value = count;
        return count;
      }
      return unreadCount.value;
    } catch (_) {
      return unreadCount.value;
    }
  }

  void incrementCount() {
    unreadCount.value++;
  }

  void decrementCount() {
    if (unreadCount.value > 0) unreadCount.value--;
  }

  void setUnreadCount(int count) {
    unreadCount.value = count;
  }

  Future<bool> markAsRead(int id) async {
    try {
      final response = await _dio.put(
        '${ApiClient.apiPrefix}/user/notifications/$id/read',
      );
      if (response.statusCode == 200) {
        decrementCount();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _dio.put(
        '${ApiClient.apiPrefix}/user/notifications/read-all',
      );
      if (response.statusCode == 200) {
        unreadCount.value = 0;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNotification(int id) async {
    try {
      final response = await _dio.delete(
        '${ApiClient.apiPrefix}/user/notifications/$id',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  List<dynamic> _extractItems(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map && payload['items'] is List) {
      return payload['items'] as List;
    }
    return const [];
  }

  int _extractUnreadCount(dynamic raw) {
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map && data['count'] != null) {
        return int.tryParse(data['count'].toString()) ?? 0;
      }
      if (data is int) return data;
      if (raw['count'] != null) {
        return int.tryParse(raw['count'].toString()) ?? 0;
      }
    }
    return 0;
  }
}
