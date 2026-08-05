import 'package:flutter_test/flutter_test.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_model.dart';

void main() {
  ChatConversation conversation({
    required String status,
    required DateTime updatedAt,
  }) {
    return ChatConversation(
      id: 1,
      orderId: 10,
      name: 'Shop',
      orderStatus: status,
      orderUpdatedAt: updatedAt,
      lastMessage: '',
      timestamp: updatedAt,
    );
  }

  test('delivered chat remains writable before four hours', () {
    final chat = conversation(
      status: 'DELIVERED',
      updatedAt: DateTime.now().subtract(
        const Duration(hours: 4) - const Duration(seconds: 1),
      ),
    );

    expect(chat.isChatWritable, isTrue);
  });

  test('delivered chat closes after four hours', () {
    final chat = conversation(
      status: 'DELIVERED',
      updatedAt: DateTime.now().subtract(const Duration(hours: 4, seconds: 1)),
    );

    expect(chat.isChatWritable, isFalse);
  });

  test('canceled chat is closed immediately', () {
    final chat = conversation(status: 'CANCELED', updatedAt: DateTime.now());

    expect(chat.isChatWritable, isFalse);
  });
}
