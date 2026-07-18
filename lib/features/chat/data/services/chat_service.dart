import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_model.dart';
import 'package:path/path.dart' as p;

/// REST client for the backend `user/chat` endpoints.
class ChatService {
  static const String _basePath = '/api/user/chat';

  static final ChatService instance = ChatService._();
  ChatService._();

  final Dio _dio = ApiClient().dio;

  bool _isOk(Response response) {
    final code = response.statusCode;
    return code != null && code >= 200 && code < 300;
  }

  Map<String, dynamic>? _body(Response response) {
    if (!_isOk(response) || response.data is! Map) return null;
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Unread message count for a single order's conversation.
  ///
  /// Returns 0 when there is no conversation yet, and `null` on a
  /// network/server error so callers can keep the last known value.
  Future<int?> getUnreadCountForOrder(int orderId) async {
    final conversation = await getConversationByOrder(orderId);
    return conversation?.unreadCount ?? 0;
  }

  Future<ChatConversation?> getConversationByOrder(int orderId) async {
    try {
      final response = await _dio.get('$_basePath/orders/$orderId');
      final body = _body(response);
      if (body != null && body['success'] == true && body['data'] is Map) {
        return ChatConversation.fromJson(
          (body['data'] as Map).cast<String, dynamic>(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('[ChatService.getConversationByOrder] $e');
      return null;
    }
  }

  Future<ChatPaged<ChatMessage>?> getMessages(
    int conversationId, {
    int page = 1,
    int size = 50,
  }) async {
    try {
      final response = await _dio.get(
        '$_basePath/conversations/$conversationId/messages',
        queryParameters: {'page': page, 'size': size},
      );
      final body = _body(response);
      if (body != null && body['success'] == true) {
        return ChatPaged.fromResponse(body, ChatMessage.fromJson);
      }
      return null;
    } catch (e) {
      debugPrint('[ChatService.getMessages] $e');
      return null;
    }
  }

  /// Creates the conversation on first send when none exists yet.
  Future<ChatMessage?> sendTextMessage(int orderId, String content) async {
    try {
      final formData = FormData.fromMap({
        'type': 'TEXT',
        'content': content,
      });
      final response = await _dio.post(
        '$_basePath/orders/$orderId/messages',
        data: formData,
      );
      final body = _body(response);
      if (body != null && body['success'] == true && body['data'] is Map) {
        return ChatMessage.fromJson(
          (body['data'] as Map).cast<String, dynamic>(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('[ChatService.sendTextMessage] $e');
      return null;
    }
  }

  /// Uploads a recorded voice note as a `VOICE` message.
  Future<ChatMessage?> sendVoiceMessage(
    int orderId,
    String filePath, {
    required int durationSeconds,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final filename = p.basename(filePath);
      final ext = p.extension(filename).toLowerCase();
      final mime = switch (ext) {
        '.m4a' || '.mp4' || '.aac' => MediaType('audio', 'mp4'),
        '.mp3' => MediaType('audio', 'mpeg'),
        '.wav' => MediaType('audio', 'wav'),
        '.ogg' => MediaType('audio', 'ogg'),
        _ => MediaType('audio', 'mp4'),
      };

      final formData = FormData();
      formData.fields.add(const MapEntry('type', 'VOICE'));
      formData.fields.add(MapEntry('durations', '$durationSeconds'));
      formData.files.add(
        MapEntry(
          'attachments',
          await MultipartFile.fromFile(
            filePath,
            filename: filename,
            contentType: mime,
          ),
        ),
      );

      final response = await _dio.post(
        '$_basePath/orders/$orderId/messages',
        data: formData,
      );
      final body = _body(response);
      if (body != null && body['success'] == true && body['data'] is Map) {
        return ChatMessage.fromJson(
          (body['data'] as Map).cast<String, dynamic>(),
        );
      }
      return null;
    } on DioException catch (e) {
      debugPrint(
        '[ChatService.sendVoiceMessage] ${e.response?.statusCode} '
        '${e.response?.data ?? e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('[ChatService.sendVoiceMessage] $e');
      return null;
    }
  }

  Future<ChatMessage?> editMessage(
    int conversationId,
    String messageId,
    String content,
  ) async {
    try {
      final response = await _dio.put(
        '$_basePath/conversations/$conversationId/messages/$messageId',
        data: {'content': content},
      );
      final body = _body(response);
      if (body != null && body['success'] == true && body['data'] is Map) {
        return ChatMessage.fromJson(
          (body['data'] as Map).cast<String, dynamic>(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('[ChatService.editMessage] $e');
      return null;
    }
  }

  /// Marks all shop messages in a conversation as read for the current user.
  Future<bool> markAsRead(int conversationId) async {
    try {
      final response = await _dio.put(
        '$_basePath/conversations/$conversationId/read',
      );
      final body = _body(response);
      return body != null && body['success'] == true;
    } catch (e) {
      debugPrint('[ChatService.markAsRead] $e');
      return false;
    }
  }

  Future<bool> deleteMessage(int conversationId, String messageId) async {
    try {
      final response = await _dio.delete(
        '$_basePath/conversations/$conversationId/messages/$messageId',
      );
      final body = _body(response);
      return body != null && body['success'] == true;
    } catch (e) {
      debugPrint('[ChatService.deleteMessage] $e');
      return false;
    }
  }
}
