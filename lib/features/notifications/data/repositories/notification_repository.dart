import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

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
    try {
      final response = await _dio.get(
        '/api/v1/mobile/notifications',
        queryParameters: {'page': page, 'size': size},
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => NotificationModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(
        '/api/v1/mobile/notifications/unread-count',
      );
      if (response.statusCode == 200 && response.data != null) {
        final count = response.data['data'] as int;
        unreadCount.value = count;
        return count;
      }
      return 0;
    } catch (e) {
      return 0;
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
      final response = await _dio.put('/api/v1/mobile/notifications/$id/read');
      if (response.statusCode == 200) {
        decrementCount();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _dio.put('/api/v1/mobile/notifications/read-all');
      if (response.statusCode == 200) {
        unreadCount.value = 0;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
