import 'dart:convert';

const String kCallChatPrefix = '::call::';

enum CallChatEvent {
  noAnswer,
  cancelled,
  declined,
  busy,
  ended,
}

enum CallDirection {
  userToShop,
  shopToUser,
}

class CallChatPayload {
  final String? callId;
  final CallChatEvent event;
  final CallDirection direction;
  final int durationSec;

  const CallChatPayload({
    this.callId,
    required this.event,
    required this.direction,
    required this.durationSec,
  });

  static CallChatPayload? tryParse(String? raw) {
    if (raw == null || !raw.startsWith(kCallChatPrefix)) return null;
    try {
      final jsonStr = raw.substring(kCallChatPrefix.length);
      final map = jsonDecode(jsonStr);
      if (map is! Map<String, dynamic>) return null;

      final eventStr = (map['event'] as String?)?.toUpperCase();
      CallChatEvent? event;
      switch (eventStr) {
        case 'NO_ANSWER':
          event = CallChatEvent.noAnswer;
          break;
        case 'CANCELLED':
          event = CallChatEvent.cancelled;
          break;
        case 'DECLINED':
          event = CallChatEvent.declined;
          break;
        case 'BUSY':
          event = CallChatEvent.busy;
          break;
        case 'ENDED':
          event = CallChatEvent.ended;
          break;
        default:
          return null;
      }

      final dirStr = (map['direction'] as String?)?.toLowerCase();
      final direction = dirStr == 'shop-to-user'
          ? CallDirection.shopToUser
          : CallDirection.userToShop;

      final durationSec = (map['durationSec'] as num?)?.toInt() ?? 0;

      return CallChatPayload(
        callId: map['callId'] as String?,
        event: event,
        direction: direction,
        durationSec: durationSec > 0 ? durationSec : 0,
      );
    } catch (_) {
      return null;
    }
  }

  static String formatDuration(int totalSeconds) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

class CallChatDescription {
  final String title;
  final String subtitle;
  final bool isMissed;

  const CallChatDescription({
    required this.title,
    required this.subtitle,
    required this.isMissed,
  });
}

CallChatDescription describeForCustomer(CallChatPayload payload) {
  final isUserCaller = payload.direction == CallDirection.userToShop;

  if (payload.event == CallChatEvent.ended) {
    return CallChatDescription(
      title: 'Call ended',
      subtitle: isUserCaller
          ? 'You called · ${CallChatPayload.formatDuration(payload.durationSec)}'
          : 'Shop called · ${CallChatPayload.formatDuration(payload.durationSec)}',
      isMissed: false,
    );
  }

  if (isUserCaller) {
    switch (payload.event) {
      case CallChatEvent.noAnswer:
        return const CallChatDescription(
          title: 'No answer',
          subtitle: 'You called · Shop didn\'t answer',
          isMissed: true,
        );
      case CallChatEvent.cancelled:
        return const CallChatDescription(
          title: 'Call cancelled',
          subtitle: 'You hung up',
          isMissed: true,
        );
      case CallChatEvent.declined:
        return const CallChatDescription(
          title: 'Call declined',
          subtitle: 'Shop declined your call',
          isMissed: true,
        );
      case CallChatEvent.busy:
        return const CallChatDescription(
          title: 'Line busy',
          subtitle: 'Shop was on another call',
          isMissed: true,
        );
      case CallChatEvent.ended:
        break;
    }
  } else {
    switch (payload.event) {
      case CallChatEvent.noAnswer:
      case CallChatEvent.cancelled:
        return const CallChatDescription(
          title: 'Missed call',
          subtitle: 'Shop called you',
          isMissed: true,
        );
      case CallChatEvent.declined:
        return const CallChatDescription(
          title: 'Call declined',
          subtitle: 'You declined the call',
          isMissed: true,
        );
      case CallChatEvent.busy:
        return const CallChatDescription(
          title: 'Missed call',
          subtitle: 'You were on another call',
          isMissed: true,
        );
      case CallChatEvent.ended:
        break;
    }
  }

  return const CallChatDescription(
    title: 'Call',
    subtitle: '',
    isMissed: false,
  );
}
