import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_model.dart';

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
      final response = await _dio.post(
        '$_basePath/orders/$orderId/messages',
        data: {'type': 'TEXT', 'content': content},
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
