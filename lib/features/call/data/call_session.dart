import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/network/websocket_service.dart';
import 'package:mytogetherapp/core/notifications/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages a single WebRTC voice call from the user side.
/// Connects to the NestJS signaling server via STOMP WebSocket + REST.
/// Supports both directions:
///   - user-to-shop: user initiates, shop answers
///   - shop-to-user: shop initiates, user answers
class CallSession {
  CallSession._() {
    _listenToCallKitEvents();
    _listenToNativeCallChannel();
    _listenForIncomingFromShop();
  }

  static final CallSession _instance = CallSession._();
  factory CallSession() => _instance;

  // Fallback TURN / STUN config used only if /api/call/ice-servers is unreachable or returns no TURN
  static const List<Map<String, dynamic>> _defaultIceServers = [
    {'urls': 'stun:stun.relay.metered.ca:80'},
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': 'turn:sg.relay.metered.ca:80',
      'username': '1d85318ad9c95e3aa7c2a929',
      'credential': 'NSOr459yCOf4CMap',
    },
    {
      'urls': 'turn:sg.relay.metered.ca:80?transport=tcp',
      'username': '1d85318ad9c95e3aa7c2a929',
      'credential': 'NSOr459yCOf4CMap',
    },
    {
      'urls': 'turn:sg.relay.metered.ca:443',
      'username': '1d85318ad9c95e3aa7c2a929',
      'credential': 'NSOr459yCOf4CMap',
    },
    {
      'urls': 'turns:sg.relay.metered.ca:443?transport=tcp',
      'username': '1d85318ad9c95e3aa7c2a929',
      'credential': 'NSOr459yCOf4CMap',
    },
  ];

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription<Map<String, dynamic>>? _callSub;
  StreamSubscription<Map<String, dynamic>>? _incomingCallSub;

  // Serialize incoming STOMP signaling events so OFFER/ANSWER complete before ICE adds
  Future<void> _signalChain = Future<void>.value();
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];
  bool _remoteDescriptionSet = false;
  String? _pendingRemoteOfferSdp;
  final Set<String> _ignoringCallKitEndIds = <String>{};

  // State notifiers for UI
  final ValueNotifier<CallState> state = ValueNotifier(CallState.idle);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> isSpeakerOn = ValueNotifier(false);

  String? _currentCallId;
  String? _direction; // 'user-to-shop' | 'shop-to-user'
  Timer? _ringTimeout;
  Timer? _reconnectTimer;
  bool _isAccepting = false;
  bool _isCleaningUp = false;

  String? currentShopName;
  String? currentShopImageUrl;
  DateTime? connectedAt;
  String? lastErrorMessage;

  String? _pendingNavCallId;
  String? _pendingNavShopName;
  void Function(String callId, String shopName)? _onCallAcceptedFromOS;

  /// Callback invoked when a shop initiates a call AND the user accepts or taps the notification.
  /// Assigning this immediately replays any buffered navigation from a cold-start CallKit accept.
  set onCallAcceptedFromOS(
    void Function(String callId, String shopName)? handler,
  ) {
    _onCallAcceptedFromOS = handler;
    if (handler != null && _pendingNavCallId != null) {
      final callId = _pendingNavCallId!;
      final shopName = _pendingNavShopName ?? currentShopName ?? 'Shop';
      _pendingNavCallId = null;
      _pendingNavShopName = null;
      handler(callId, shopName);
    }
  }

  void Function(String callId, String shopName)? get onCallAcceptedFromOS =>
      _onCallAcceptedFromOS;

  final Dio _dio = ApiClient().dio;

  static const MethodChannel _activeCallChannel =
      MethodChannel('com.mytogether/active_call');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _listenToNativeCallChannel() {
    if (!_isAndroid) return;
    _activeCallChannel.setMethodCallHandler((call) async {
      if (call.method == 'endCallFromNotification') {
        await endCall();
      }
    });
  }

  void _startActiveCallNotification(String callerName) {
    if (!_isAndroid) return;
    unawaited(
      _activeCallChannel.invokeMethod('start', {
        'callerName': callerName,
        'baseTime': 0, // Let native ActiveCallService use SystemClock.elapsedRealtime()
      }).catchError((e) {
        if (kDebugMode) debugPrint('ActiveCallService start ignored: $e');
      }),
    );
  }

  void _stopActiveCallNotification() {
    if (!_isAndroid) return;
    unawaited(
      _activeCallChannel.invokeMethod('stop').catchError((e) {
        if (kDebugMode) debugPrint('ActiveCallService stop ignored: $e');
      }),
    );
  }

  void _triggerOSNavigation(String callId, String shopName) {
    final handler = _onCallAcceptedFromOS;
    if (handler != null) {
      handler(callId, shopName);
    } else {
      _pendingNavCallId = callId;
      _pendingNavShopName = shopName;
    }
  }

  void _listenToCallKitEvents() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
        unawaited(NotificationService().registerVoipToken());
        return;
      } else if (event is CallEventActionCallIncoming) {
        final rawExtraId = event.callKitParams.extra?['callId']?.toString();
        final id = (rawExtraId != null && rawExtraId.isNotEmpty)
            ? rawExtraId
            : event.callKitParams.id;
        if (id.isEmpty) return;
        final extraName = event.callKitParams.extra?['callerName']?.toString();
        final callerName = (event.callKitParams.nameCaller?.isNotEmpty == true)
            ? event.callKitParams.nameCaller!
            : (extraName ?? currentShopName ?? 'Shop');
        if (_currentCallId == null && state.value == CallState.idle) {
          _currentCallId = id;
          _direction = 'shop-to-user';
          currentShopName = callerName;
          state.value = CallState.ringing;
          _ensureWebSocketConnected();
          _listenForCallEvents();
          _ringTimeout?.cancel();
          _ringTimeout = Timer(const Duration(seconds: 62), () {
            if (state.value == CallState.ringing) {
              _cleanup(targetState: CallState.idle);
            }
          });
        }
      } else if (event is CallEventActionCallDecline) {
        final rawExtraId = event.callKitParams.extra?['callId']?.toString();
        final id = (rawExtraId != null && rawExtraId.isNotEmpty)
            ? rawExtraId
            : event.callKitParams.id;
        if (id.isEmpty) return;
        if (_currentCallId == null) {
          // App woke up from killed/background state where FCM/PushKit showed CallKit
          unawaited(
            _dio
                .post('/api/call/user-reject/$id',
                    options: Options(extra: {'skipRetry': true}))
                .catchError((_) => Response(requestOptions: RequestOptions())),
          );
          return;
        }
        if (id == _currentCallId) {
          if (_direction == 'shop-to-user' && state.value == CallState.ringing) {
            unawaited(rejectIncomingCall(fromCallKit: true));
          } else {
            unawaited(endCall());
          }
        }
      } else if (event is CallEventActionCallAccept) {
        final rawExtraId = event.callKitParams.extra?['callId']?.toString();
        final id = (rawExtraId != null && rawExtraId.isNotEmpty)
            ? rawExtraId
            : event.callKitParams.id;
        if (id.isEmpty) return;
        final extraName = event.callKitParams.extra?['callerName']?.toString();
        final callerName = (event.callKitParams.nameCaller?.isNotEmpty == true)
            ? event.callKitParams.nameCaller!
            : (extraName ?? currentShopName ?? 'Shop');

        if (_currentCallId == null && state.value == CallState.idle) {
          // Recover session when incoming call arrived via PushKit or FCM background isolate
          _currentCallId = id;
          _direction = 'shop-to-user';
          currentShopName = callerName;
          _ensureWebSocketConnected();
          _listenForCallEvents();
        }

        if (_currentCallId == id && _direction == 'shop-to-user') {
          unawaited(acceptIncomingCall(fromCallKit: true));
          _triggerOSNavigation(id, currentShopName ?? callerName);
        }
      } else if (event is CallEventActionCallEnded) {
        final rawExtraId = event.callKitParams.extra?['callId']?.toString();
        final id = (rawExtraId != null && rawExtraId.isNotEmpty)
            ? rawExtraId
            : event.callKitParams.id;
        if (_ignoringCallKitEndIds.remove(id) ||
            _ignoringCallKitEndIds.remove(event.callKitParams.id)) {
          return;
        }
        if (_currentCallId != null &&
            (id == _currentCallId || event.callKitParams.id == _currentCallId)) {
          unawaited(endCall());
        }
      } else if (event is CallEventActionCallToggleMute) {
        if (_currentCallId != null &&
            (event.id == _currentCallId || event.id.isNotEmpty)) {
          isMuted.value = event.isMuted;
          _localStream?.getAudioTracks().forEach((track) {
            track.enabled = !event.isMuted;
          });
        }
      } else if (event is CallEventActionCallCallback) {
        final id = event.id;
        if (_currentCallId != null && id == _currentCallId) {
          _triggerOSNavigation(_currentCallId!, currentShopName ?? 'Shop');
        }
      }
    });
  }

  /// Checks whether CallKit already has an accepted or ringing call from a cold start.
  Future<void> checkAndRestoreActiveCall() async {
    if (kIsWeb) return;
    if (_currentCallId != null || state.value != CallState.idle) return;
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls.isEmpty) return;

      final CallKitParams callParams = activeCalls.first;
      final extra = callParams.extra ?? const <String, dynamic>{};
      final rawExtraId = extra['callId']?.toString();
      final callId = (rawExtraId != null && rawExtraId.isNotEmpty)
          ? rawExtraId
          : callParams.id;
      if (callId.isEmpty) return;
      final callerName = (callParams.nameCaller?.isNotEmpty == true)
          ? callParams.nameCaller!
          : (extra['callerName']?.toString() ?? 'Shop');
      final isAccepted = callParams.isAccepted;

      _currentCallId = callId;
      _direction = 'shop-to-user';
      currentShopName = callerName;
      _ensureWebSocketConnected();
      _listenForCallEvents();

      if (isAccepted) {
        await acceptIncomingCall(fromCallKit: true);
        _triggerOSNavigation(callId, callerName);
      } else {
        state.value = CallState.ringing;
        _ringTimeout?.cancel();
        _ringTimeout = Timer(const Duration(seconds: 62), () {
          if (state.value == CallState.ringing) {
            _cleanup(targetState: CallState.idle);
          }
        });
        _triggerOSNavigation(callId, callerName);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('checkAndRestoreActiveCall error: $e');
    }
  }

  /// Handles an incoming call delivered via FCM when foreground WebSocket was offline
  /// or when the user tapped the iOS incoming-call notification banner.
  Future<void> handleIncomingFromPush(
    Map<String, dynamic> data, {
    bool openScreen = false,
  }) async {
    final callId = data['callId']?.toString();
    if (callId == null || callId.isEmpty) return;
    final callerName = data['callerName']?.toString() ?? 'Shop';

    if (_currentCallId == callId) {
      if (openScreen) _triggerOSNavigation(callId, callerName);
      return;
    }
    if (state.value != CallState.idle) return;

    _startRingingIncoming(
      callId: callId,
      callerName: callerName,
      showCallKit: !openScreen,
    );
    if (openScreen) {
      _triggerOSNavigation(callId, callerName);
    }
  }

  // ──────────────────────────────────────────────
  // USER → SHOP call flow
  // ──────────────────────────────────────────────

  /// User initiates a call to [shopId]. Returns false if call fails to start.
  Future<bool> initiateCall({
    required int shopId,
    required String shopName,
    String? shopImageUrl,
    int? orderId,
  }) async {
    lastErrorMessage = null;
    if (state.value != CallState.idle) {
      lastErrorMessage = 'You are already on another call.';
      return false;
    }

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        lastErrorMessage = 'Microphone permission is required to make calls.';
        return false;
      }
    }

    _ensureWebSocketConnected();

    currentShopName = shopName;
    currentShopImageUrl = shopImageUrl;
    _direction = 'user-to-shop';
    state.value = CallState.calling;

    try {
      final resp = await _dio.post(
        '/api/call/initiate/$shopId',
        data: orderId != null ? {'orderId': orderId} : null,
        options: Options(extra: {'skipRetry': true}),
      );
      _currentCallId = resp.data['data']['callId'] as String?;
      if (_currentCallId == null) {
        lastErrorMessage = 'Could not start call. Please try again.';
        state.value = CallState.idle;
        _direction = null;
        return false;
      }

      _listenForCallEvents();

      // Slightly longer than backend 60s timeout so server CALL_TIMEOUT arrives first
      _ringTimeout?.cancel();
      _ringTimeout = Timer(const Duration(seconds: 62), () {
        if (state.value == CallState.calling) {
          unawaited(endCall());
        }
      });

      return true;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      lastErrorMessage = (msg != null && msg.isNotEmpty)
          ? msg
          : 'Could not connect call. Please try again.';
      state.value = CallState.idle;
      _direction = null;
      currentShopName = null;
      currentShopImageUrl = null;
      return false;
    } catch (_) {
      lastErrorMessage = 'Could not connect call. Please try again.';
      state.value = CallState.idle;
      _direction = null;
      currentShopName = null;
      currentShopImageUrl = null;
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // SHOP → USER call flow
  // ──────────────────────────────────────────────

  void _listenForIncomingFromShop() {
    _incomingCallSub?.cancel();
    _incomingCallSub = WebSocketService().callUpdates.listen((event) {
      final type = event['type'] as String?;
      if (type == 'CALL_INCOMING' && state.value == CallState.idle) {
        final callId = event['callId'] as String?;
        final shopId = event['shopId'];
        final callerName = event['callerName'] as String? ?? 'Shop';
        if (callId == null || shopId == null) return;

        _startRingingIncoming(
          callId: callId,
          callerName: callerName,
          showCallKit: true,
        );
      }
    });
  }

  void _startRingingIncoming({
    required String callId,
    required String callerName,
    required bool showCallKit,
  }) {
    _currentCallId = callId;
    _direction = 'shop-to-user';
    currentShopName = callerName;
    state.value = CallState.ringing;

    if (showCallKit) {
      unawaited(_showIncomingCallUI(callId: callId, callerName: callerName));
    }

    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 62), () {
      if (state.value == CallState.ringing) {
        _cleanup(targetState: CallState.idle);
      }
    });

    _listenForCallEvents();
  }

  /// Show OS-level incoming call notification/screen (shop-to-user).
  Future<void> _showIncomingCallUI({
    required String callId,
    required String callerName,
  }) async {
    final callKitParams = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'MyTogether',
      avatar: '',
      handle: 'Incoming Call',
      type: 0,
      duration: 60000,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call from shop',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{
        'callId': callId,
        'callerName': callerName,
        'direction': 'shop-to-user',
      },
      headers: <String, dynamic>{},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#EF4444',
        actionColor: '#22C55E',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: '',
        supportsVideo: false,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  }

  /// User accepts an incoming call from shop.
  /// IMPORTANT: Sets up PeerConnection & mic BEFORE notifying backend so incoming CALL_OFFER is never dropped.
  Future<void> acceptIncomingCall({bool fromCallKit = false}) async {
    if (_currentCallId == null || _direction != 'shop-to-user') return;
    if (_isAccepting || state.value == CallState.connected) return;
    _isAccepting = true;
    final activeCallId = _currentCallId!;

    try {
      _ringTimeout?.cancel();

      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          lastErrorMessage = 'Microphone permission is required for voice calls.';
          await rejectIncomingCall(fromCallKit: fromCallKit);
          return;
        }
      }

      if (!fromCallKit) {
        _dismissCallKitSafely(activeCallId);
      }

      state.value = CallState.connected;
      connectedAt ??= DateTime.now();
      _startActiveCallNotification(currentShopName ?? 'Shop');

      await _ensureWebSocketConnectedAndReady();

      final ready = await _setupPeerConnection();
      if (!ready || _currentCallId != activeCallId) {
        await endCall();
        return;
      }

      try {
        await _dio.post(
          '/api/call/user-accept/$activeCallId',
          options: Options(extra: {'skipRetry': true}),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('user-accept failed: $e');
        await endCall();
        return;
      }

      // If CALL_OFFER raced in right after accept, process it now
      if (_pendingRemoteOfferSdp != null) {
        final sdp = _pendingRemoteOfferSdp!;
        _pendingRemoteOfferSdp = null;
        await _processRemoteOffer(sdp);
      }
    } finally {
      _isAccepting = false;
    }
  }

  /// User rejects an incoming call from shop.
  Future<void> rejectIncomingCall({bool fromCallKit = false}) async {
    final callId = _currentCallId;
    if (callId == null) return;
    if (!fromCallKit) {
      _dismissCallKitSafely(callId);
    }
    try {
      await _dio.post(
        '/api/call/user-reject/$callId',
        options: Options(extra: {'skipRetry': true}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('call_session.dart: reject error: $e');
    }
    _cleanup(targetState: CallState.idle);
  }

  // ──────────────────────────────────────────────
  // Shared
  // ──────────────────────────────────────────────

  /// End the current call (user side).
  Future<void> endCall() async {
    final callId = _currentCallId;
    if (callId == null || _isCleaningUp) {
      if (state.value != CallState.idle) {
        _cleanup(targetState: CallState.idle);
      }
      return;
    }
    _cleanup(targetState: CallState.idle);
    try {
      await _dio.post(
        '/api/call/end/$callId',
        options: Options(extra: {'skipRetry': true}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('call_session.dart: end error: $e');
    }
  }

  /// Mute / unmute local mic.
  void toggleMute() {
    final audioTracks = _localStream?.getAudioTracks() ?? [];
    for (final track in audioTracks) {
      track.enabled = !track.enabled;
    }
    isMuted.value = !isMuted.value;
  }

  /// Toggle speakerphone.
  void toggleSpeaker() {
    isSpeakerOn.value = !isSpeakerOn.value;
    if (!kIsWeb) {
      unawaited(
        Helper.setSpeakerphoneOn(isSpeakerOn.value).catchError((e) {
          if (kDebugMode) debugPrint('toggleSpeaker error: $e');
        }),
      );
    }
  }

  void _ensureWebSocketConnected() {
    if (!WebSocketService().isConnected) {
      WebSocketService().connect();
    }
  }

  Future<void> _ensureWebSocketConnectedAndReady() async {
    if (WebSocketService().isConnected) return;
    WebSocketService().connect();
    final completer = Completer<void>();
    late VoidCallback listener;
    listener = () {
      if (WebSocketService().isConnected && !completer.isCompleted) {
        WebSocketService().connectionStatus.removeListener(listener);
        completer.complete();
      }
    };
    WebSocketService().connectionStatus.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        WebSocketService().connectionStatus.removeListener(listener);
      },
    );
  }

  void _listenForCallEvents() {
    _callSub?.cancel();
    _callSub = WebSocketService().callUpdates.listen((event) {
      _signalChain = _signalChain
          .then((_) => _handleCallEvent(event))
          .catchError((e) {
        if (kDebugMode) debugPrint('Signal handling error: $e');
      });
    });
  }

  Future<void> _handleCallEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    final callId = event['callId'] as String?;
    if (callId == null || callId != _currentCallId) return;

    switch (type) {
      case 'CALL_ACCEPTED':
        if (_direction == 'user-to-shop') {
          _ringTimeout?.cancel();
          state.value = CallState.connected;
          connectedAt ??= DateTime.now();
          _startActiveCallNotification(currentShopName ?? 'Shop');
          await _startWebRTCAsOfferer();
        }
        break;

      case 'CALL_REJECTED':
        _ringTimeout?.cancel();
        state.value = CallState.rejected;
        await Future.delayed(const Duration(seconds: 2));
        if (_currentCallId == callId) {
          _cleanup(targetState: CallState.idle);
        }
        break;

      case 'CALL_BUSY':
        _ringTimeout?.cancel();
        state.value = CallState.busy;
        await Future.delayed(const Duration(seconds: 2));
        if (_currentCallId == callId) {
          _cleanup(targetState: CallState.idle);
        }
        break;

      case 'CALL_TIMEOUT':
        _ringTimeout?.cancel();
        state.value = CallState.noAnswer;
        await Future.delayed(const Duration(seconds: 2));
        if (_currentCallId == callId) {
          _cleanup(targetState: CallState.idle);
        }
        break;

      case 'CALL_OFFER':
        final sdp = event['sdp'] as String?;
        if (sdp == null || sdp.isEmpty) return;
        if (_peerConnection == null) {
          _pendingRemoteOfferSdp = sdp;
          return;
        }
        await _processRemoteOffer(sdp);
        break;

      case 'CALL_ANSWER':
        final sdp = event['sdp'] as String?;
        if (sdp != null && sdp.isNotEmpty && _peerConnection != null) {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(sdp, 'answer'),
          );
          _remoteDescriptionSet = true;
          await _flushPendingIceCandidates();
        }
        break;

      case 'CALL_ICE':
        final candidateJson = event['candidate'] as String?;
        if (candidateJson != null && candidateJson.isNotEmpty) {
          final c = json.decode(candidateJson) as Map<String, dynamic>;
          final ice = RTCIceCandidate(
            c['candidate'] as String?,
            c['sdpMid'] as String?,
            (c['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_peerConnection == null || !_remoteDescriptionSet) {
            _pendingRemoteCandidates.add(ice);
          } else {
            try {
              await _peerConnection!.addCandidate(ice);
            } catch (e) {
              if (kDebugMode) debugPrint('addCandidate ignored: $e');
            }
          }
        }
        break;

      case 'CALL_END':
      case 'CALL_ANSWERED_ELSEWHERE':
        _cleanup(targetState: CallState.idle);
        break;
    }
  }

  Future<void> _processRemoteOffer(String sdp) async {
    final pc = _peerConnection;
    final activeCallId = _currentCallId;
    if (pc == null || activeCallId == null) return;

    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    _remoteDescriptionSet = true;
    await _flushPendingIceCandidates();

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    try {
      await _dio.post(
        '/api/call/answer/$activeCallId',
        data: {'sdp': answer.sdp},
        options: Options(extra: {'skipRetry': true}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('call_session.dart: answer error: $e');
    }
  }

  Future<void> _flushPendingIceCandidates() async {
    final pc = _peerConnection;
    if (pc == null || !_remoteDescriptionSet) return;
    final pending = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final ice in pending) {
      try {
        await pc.addCandidate(ice);
      } catch (e) {
        if (kDebugMode) debugPrint('flush addCandidate ignored: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIceServers() async {
    try {
      final resp = await _dio.get(
        '/api/call/ice-servers',
        options: Options(
          sendTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
          extra: {'skipRetry': true},
        ),
      );
      final raw = resp.data?['data']?['iceServers'] ?? resp.data?['iceServers'];
      if (raw is List && raw.isNotEmpty) {
        final list = raw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        final hasTurn = list.any(
          (s) => (s['urls']?.toString() ?? '').startsWith('turn'),
        );
        if (hasTurn) return list;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getIceServers fallback used: $e');
    }
    return _defaultIceServers;
  }

  /// Shared PeerConnection + local mic setup for both Offerer and Answerer.
  Future<bool> _setupPeerConnection() async {
    final iceServers = await _fetchIceServers();
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _peerConnection = pc;
    _remoteDescriptionSet = false;

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    } catch (e) {
      lastErrorMessage = 'Microphone access failed.';
      if (kDebugMode) debugPrint('getUserMedia failed: $e');
      return false;
    }

    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
      }
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) async {
      final callId = _currentCallId;
      if (callId == null ||
          candidate.candidate == null ||
          candidate.candidate!.isEmpty) {
        return;
      }
      try {
        await _dio.post(
          '/api/call/ice/$callId',
          data: {
            'candidate': json.encode({
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }),
          },
          options: Options(extra: {'skipRetry': true}),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('call_session.dart: ice error: $e');
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState iceState) {
      if (_currentCallId == null) return;
      if (iceState == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        state.value = CallState.reconnecting;
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 30), () {
          if (state.value == CallState.reconnecting) {
            unawaited(endCall());
          }
        });
      } else if (iceState ==
              RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _reconnectTimer?.cancel();
        connectedAt ??= DateTime.now();
        state.value = CallState.connected;
      } else if (iceState ==
              RTCIceConnectionState.RTCIceConnectionStateFailed ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _reconnectTimer?.cancel();
        unawaited(endCall());
      }
    };

    return true;
  }

  /// User is Offerer (user-to-shop): creates offer and sends to shop.
  Future<void> _startWebRTCAsOfferer() async {
    final activeCallId = _currentCallId;
    if (activeCallId == null) return;

    final ready = await _setupPeerConnection();
    if (!ready || _currentCallId != activeCallId || _peerConnection == null) {
      await endCall();
      return;
    }

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
    });
    await _peerConnection!.setLocalDescription(offer);

    try {
      await _dio.post(
        '/api/call/offer/$activeCallId',
        data: {'sdp': offer.sdp},
        options: Options(extra: {'skipRetry': true}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('call_session.dart: offer error: $e');
      await endCall();
    }
  }

  void _dismissCallKitSafely(String callId) {
    if (kIsWeb) return;
    _ignoringCallKitEndIds.add(callId);
    unawaited(
      FlutterCallkitIncoming.endCall(callId).catchError((_) {}),
    );
  }

  void _cleanup({CallState targetState = CallState.idle}) {
    if (_isCleaningUp) return;
    _isCleaningUp = true;
    try {
      _stopActiveCallNotification();
      final callId = _currentCallId;
      if (callId != null) {
        _dismissCallKitSafely(callId);
      }

      _ringTimeout?.cancel();
      _ringTimeout = null;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _callSub?.cancel();
      _callSub = null;

      _peerConnection?.close();
      _peerConnection?.dispose();
      _peerConnection = null;

      _localStream?.getTracks().forEach((t) => t.stop());
      _localStream?.dispose();
      _localStream = null;

      _remoteStream?.getTracks().forEach((t) => t.stop());
      _remoteStream?.dispose();
      _remoteStream = null;

      _pendingRemoteCandidates.clear();
      _remoteDescriptionSet = false;
      _pendingRemoteOfferSdp = null;
      _isAccepting = false;

      _currentCallId = null;
      _direction = null;
      currentShopName = null;
      currentShopImageUrl = null;
      connectedAt = null;
      isMuted.value = false;
      final wasSpeakerOn = isSpeakerOn.value;
      isSpeakerOn.value = false;
      if (!kIsWeb && wasSpeakerOn) {
        unawaited(Helper.setSpeakerphoneOn(false).catchError((_) {}));
      }

      state.value = targetState;
      _listenForIncomingFromShop();
    } finally {
      _isCleaningUp = false;
    }
  }
}

enum CallState {
  idle,
  calling,
  ringing,
  connected,
  reconnecting,
  rejected,
  busy,
  noAnswer,
  ended,
}
