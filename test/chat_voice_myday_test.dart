import 'package:flutter_test/flutter_test.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_model.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_voice_player.dart';
import 'package:mytogetherapp/features/home/data/models/shop_dto.dart';

void main() {
  group('ChatMessage voice parsing', () {
    test('parses VOICE attachments and duration', () {
      final message = ChatMessage.fromJson({
        'id': 42,
        'conversationId': 7,
        'senderType': 'USER',
        'type': 'VOICE',
        'content': null,
        'isRead': false,
        'isDeleted': false,
        'createdAt': '2026-07-17T10:00:00.000Z',
        'attachments': [
          {
            'id': 9,
            'type': 'VOICE',
            'url': 'https://cdn.example.com/chat/voice.m4a',
            'mimeType': 'audio/mp4',
            'fileSize': 12345,
            'duration': 12,
            'sortOrder': 0,
          },
        ],
      });

      expect(message.kind, ChatMessageKind.voice);
      expect(message.isVoice, isTrue);
      expect(message.voiceUrl, 'https://cdn.example.com/chat/voice.m4a');
      expect(message.voiceDurationSeconds, 12);
      expect(message.attachments, hasLength(1));
      expect(message.attachments.first.kind, ChatAttachmentKind.voice);
    });

    test('preview shows voice label', () {
      expect(
        ChatConversation.previewFor({
          'type': 'VOICE',
          'content': null,
          'isDeleted': false,
        }),
        '🎤 Voice message',
      );
    });
  });

  group('voice playback speed', () {
    test('cycles 1x → 1.5x → 2x → 1x', () {
      expect(nextVoicePlaybackSpeed(1.0), 1.5);
      expect(nextVoicePlaybackSpeed(1.5), 2.0);
      expect(nextVoicePlaybackSpeed(2.0), 1.0);
      expect(formatVoicePlaybackSpeed(1.5), '1.5x');
      expect(formatVoiceDuration(const Duration(seconds: 75)), '01:15');
    });
  });

  group('ShopMyDayDto', () {
    test('parses active shop myDays and filters expired', () {
      final now = DateTime.now();
      final detail = ShopDetailDto.fromJson({
        'id': 1,
        'name': 'Test Shop',
        'rating': 4.5,
        'reviewCount': 10,
        'distance': 1.2,
        'isOpen': true,
        'isFavorite': false,
        'operatingHours': [],
        'photos': [],
        'popularDishes': [],
        'recommendations': [],
        'hotDeals': [],
        'myDays': [
          {
            'id': 1,
            'shopId': 1,
            'imageUrl': 'https://cdn.example.com/shop-mydays/a.jpg',
            'createdAt': now.toIso8601String(),
            'expiresAt': now.add(const Duration(hours: 12)).toIso8601String(),
          },
          {
            'id': 2,
            'shopId': 1,
            'imageUrl': 'https://cdn.example.com/shop-mydays/b.jpg',
            'createdAt': now.subtract(const Duration(hours: 30)).toIso8601String(),
            'expiresAt': now.subtract(const Duration(hours: 6)).toIso8601String(),
          },
        ],
      });

      expect(detail.myDays, hasLength(1));
      expect(detail.myDays.first.id, 1);
      expect(detail.myDays.first.isActive, isTrue);
    });
  });
}
