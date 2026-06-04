import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/announcement_model.dart';

/// Recipient-facing announcements (admin broadcasts), separate from the
/// order-notification feed. Backend (`dev`):
///   GET    /api/announcements
///   GET    /api/announcements/unread-count
///   PUT    /api/announcements/read-all
///   PUT    /api/announcements/:id/read
///   DELETE /api/announcements/:id   (per-recipient dismiss)
class AnnouncementRepository {
  static final AnnouncementRepository _instance =
      AnnouncementRepository._internal();
  factory AnnouncementRepository() => _instance;
  AnnouncementRepository._internal();

  final Dio _dio = ApiClient().dio;

  /// Reactive unread count for badges.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<List<AnnouncementModel>> getAnnouncements({
    int page = 1,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '${ApiClient.apiPrefix}/announcements',
      queryParameters: {'page': page, 'size': size},
    );

    if (response.statusCode != 200 || response.data == null) {
      return [];
    }

    final raw = response.data;
    final List<dynamic> list = raw is Map
        ? (raw['data'] as List<dynamic>? ?? const [])
        : (raw is List ? raw : const []);

    return list
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(
        '${ApiClient.apiPrefix}/announcements/unread-count',
      );
      if (response.statusCode == 200 && response.data != null) {
        final count = _extractCount(response.data);
        unreadCount.value = count;
        return count;
      }
      return unreadCount.value;
    } catch (_) {
      return unreadCount.value;
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      final response = await _dio.put(
        '${ApiClient.apiPrefix}/announcements/$id/read',
      );
      if (response.statusCode == 200) {
        if (unreadCount.value > 0) unreadCount.value--;
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
        '${ApiClient.apiPrefix}/announcements/read-all',
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

  Future<bool> dismiss(int id) async {
    try {
      final response = await _dio.delete(
        '${ApiClient.apiPrefix}/announcements/$id',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  int _extractCount(dynamic raw) {
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
