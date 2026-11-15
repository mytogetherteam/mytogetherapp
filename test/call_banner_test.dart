import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytogetherapp/features/call/data/call_session.dart';
import 'package:mytogetherapp/features/call/presentation/screens/call_screen.dart';
import 'package:mytogetherapp/features/call/presentation/widgets/floating_call_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callKitChannel = MethodChannel('flutter_callkit_incoming');
  const activeCallChannel = MethodChannel('com.mytogether/active_call');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(callKitChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(activeCallChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(callKitChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(activeCallChannel, null);
  });

  testWidgets(
      'FloatingCallBanner renders inside Stack -> Positioned without ParentDataWidget error',
      (tester) async {
    final session = CallSession();
    CallScreen.isVisibleNotifier.value = false;
    session.currentShopName = 'My Test Shop';
    session.connectedAt = DateTime.now().subtract(const Duration(seconds: 12));
    session.state.value = CallState.connected;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FloatingCallBanner(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('My Test Shop'), findsOneWidget);

    session.state.value = CallState.idle;
    session.currentShopName = null;
    session.connectedAt = null;
    await tester.pump();
  });

  test('handleIncomingFromPush transitions idle session to ringing and handles missing callId safely', () async {
    final session = CallSession();
    session.state.value = CallState.idle;

    await session.handleIncomingFromPush({});
    expect(session.state.value, CallState.idle);

    await session.handleIncomingFromPush({
      'callId': 'call-123',
      'callerName': 'Noodle House',
    });

    expect(session.state.value, CallState.ringing);
    expect(session.currentShopName, 'Noodle House');

    await session.endCall();
    expect(session.state.value, CallState.idle);
  });
}

