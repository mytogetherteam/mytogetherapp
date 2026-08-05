import 'package:flutter_test/flutter_test.dart';
import 'package:mytogetherapp/core/localization/app_language.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_model.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_window.dart';

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

  test('time left is null without a deadline or once it passed', () {
    expect(ChatWindow.timeLeftUntil(null), isNull);
    expect(
      ChatWindow.timeLeftUntil(
        DateTime.now().subtract(const Duration(hours: 1)),
      ),
      isNull,
    );
    expect(
      ChatWindow.timeLeftUntil(DateTime.now().add(const Duration(minutes: 30))),
      isNotNull,
    );
  });

  test('countdown uses the active language units', () async {
    await LocaleController.instance.setLanguage(AppLanguage.en);
    expect(
      LocaleController.instance.countdown(
        const Duration(hours: 3, minutes: 52),
      ),
      '3\u00A0hr 52\u00A0min',
    );
    expect(
      LocaleController.instance.countdown(const Duration(minutes: 8)),
      '8\u00A0min',
    );

    await LocaleController.instance.setLanguage(AppLanguage.mm);
    expect(
      LocaleController.instance.countdown(const Duration(hours: 2)),
      '2\u00A0နာရီ',
    );
  });

  test('countdown never separates a value from its unit', () async {
    for (final language in AppLanguage.values) {
      await LocaleController.instance.setLanguage(language);
      final countdown = LocaleController.instance.countdown(
        const Duration(hours: 3, minutes: 13),
      );

      expect(countdown, contains('3\u00A0'), reason: '${language.code} hours');
      expect(
        countdown,
        contains('13\u00A0'),
        reason: '${language.code} minutes',
      );
      expect(
        RegExp(r'\d \S').hasMatch(countdown),
        isFalse,
        reason: '${language.code} allows a line break after a number',
      );
    }
  });

  test('window hint states both the 4-hour rule and the time left', () async {
    await LocaleController.instance.setLanguage(AppLanguage.en);
    final closesAt = DateTime.now().add(const Duration(hours: 3, minutes: 52));
    final timeLeft = ChatWindow.timeLeftUntil(closesAt)!;

    final hint = LocaleController.instance.trArgs('chat.window_hint', {
      'time': LocaleController.instance.countdown(timeLeft),
    });

    expect(hint, contains('4 hours'));
    expect(hint, contains('3\u00A0hr 52\u00A0min'));
    // The countdown leads so it stays on the first line, unbroken.
    expect(hint, startsWith('3\u00A0hr 52\u00A0min\u00A0left'));
  });
}
