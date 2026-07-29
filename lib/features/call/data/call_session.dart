import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/network/websocket_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages a single WebRTC voice call from the user side.
/// Connects to the NestJS signaling server via existing STOMP WebSocket.
class CallSession {
  CallSession._() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      if (event is CallEventActionCallDecline) {
        if (_currentCallId != null && event.callKitParams.id == _currentCallId) {
          endCall();
        }
      } else if (event is CallEventActionCallEnded) {
        if (_currentCallId != null && event.callKitParams.id == _currentCallId) {
          endCall();
        }
      }
    });
  }
  static final CallSession _instance = CallSession._();
  factory CallSession() => _instance;

  // STOMP destination for call events directed at the user

  // TURN / STUN server config — uses Metered.ca free tier (50GB/month)
  // Replace with your own Coturn server once set up on EC2.
  static const List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    // Add your Coturn TURN server here after AWS setup:
    // {
    //   'urls': 'turn:api.mytogether.org:3478',
    //   'username': 'mytogether',
    //   'credential': 'strongpassword123',
    // },
  ];

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription<Map<String, dynamic>>? _callSub;

  // State notifiers for UI
  final ValueNotifier<CallState> state = ValueNotifier(CallState.idle);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> isSpeakerOn = ValueNotifier(false);

  String? _currentCallId;
  Timer? _ringTimeout;
  
  String? currentShopName;
  String? currentShopImageUrl;

  final Dio _dio = ApiClient().dio;

  /// User initiates a call to [shopId]. Returns false if call fails to start.
  Future<bool> initiateCall({required int shopId, required String shopName, String? shopImageUrl}) async {
    if (state.value != CallState.idle) return false;

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return false;
      }
    }

    currentShopName = shopName;
    currentShopImageUrl = shopImageUrl;

    state.value = CallState.calling;

    try {
      final resp = await _dio.post(
        '/api/call/initiate/$shopId',
      );
      _currentCallId = resp.data['data']['callId'] as String?;
      if (_currentCallId == null) {
        state.value = CallState.idle;
        return false;
      }

      final callKitParams = CallKitParams(
        id: _currentCallId!,
        nameCaller: shopName,
        appName: 'MyTogether',
        avatar: shopImageUrl ?? '',
        handle: 'Shop Call',
        type: 1, // audio
        duration: 30000,
        missedCallNotification: const NotificationParams(
          showNotification: false,
          isShowCallback: false,
          subtitle: 'Missed call',
          callbackText: 'Call back',
        ),
        extra: <String, dynamic>{},
        headers: <String, dynamic>{},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#22C55E',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call",
        ),
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: '',
          supportsVideo: false,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
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
      await FlutterCallkitIncoming.startCall(callKitParams);

      // Subscribe to incoming call events via STOMP
      _listenForCallEvents();

      // Timeout UI if no response in 30s
      _ringTimeout = Timer(const Duration(seconds: 31), () {
        if (state.value == CallState.calling) {
          state.value = CallState.idle;
          _cleanup();
        }
      });

      return true;
    } catch (e) {
      debugPrint('[CallSession] initiateCall error: $e');
      state.value = CallState.idle;
      return false;
    }
  }

  /// End the current call (user side).
  Future<void> endCall() async {
    if (_currentCallId == null) return;
    try {
      await _dio.post('/api/call/end/$_currentCallId');
    } catch (_) {}
    _cleanup();
    state.value = CallState.idle;
  }

  /// Mute / unmute local mic.
  void toggleMute() {
    final audioTracks = _localStream?.getAudioTracks() ?? [];
    for (final track in audioTracks) {
      track.enabled = !track.enabled;
    }
    isMuted.value = !isMuted.value;
  }

  void _listenForCallEvents() {
    _callSub?.cancel();
    _callSub = WebSocketService().callUpdates.listen(_handleCallEvent);
  }

  Future<void> _handleCallEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    final callId = event['callId'] as String?;
    if (callId != _currentCallId) return;

    switch (type) {
      case 'CALL_ACCEPTED':
        _ringTimeout?.cancel();
        state.value = CallState.connected;
        await _startWebRTC();
        break;

      case 'CALL_REJECTED':
        state.value = CallState.rejected;
        await Future.delayed(const Duration(seconds: 2));
        state.value = CallState.idle;
        _cleanup();
        break;

      case 'CALL_TIMEOUT':
        state.value = CallState.noAnswer;
        await Future.delayed(const Duration(seconds: 2));
        state.value = CallState.idle;
        _cleanup();
        break;

      case 'CALL_ANSWER':
        final sdp = event['sdp'] as String?;
        if (sdp != null && _peerConnection != null) {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(sdp, 'answer'),
          );
        }
        break;

      case 'CALL_ICE':
        final candidateJson = event['candidate'] as String?;
        if (candidateJson != null && _peerConnection != null) {
          final c = json.decode(candidateJson) as Map<String, dynamic>;
          await _peerConnection!.addCandidate(RTCIceCandidate(
            c['candidate'] as String,
            c['sdpMid'] as String?,
            c['sdpMLineIndex'] as int?,
          ));
        }
        break;

      case 'CALL_END':
        state.value = CallState.idle;
        _cleanup();
        break;
    }
  }

  Future<void> _startWebRTC() async {
    _peerConnection = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });

    // Get local audio
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Handle remote audio stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
      }
    };

    // Send ICE candidates to server as they are discovered
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
      if (_currentCallId == null) return;
      try {
        await _dio.post('/api/call/ice/$_currentCallId', data: {
          'candidate': json.encode({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }),
        });
      } catch (_) {}
    };

    // Create and send SDP offer
    final offer = await _peerConnection!.createOffer({'offerToReceiveAudio': true});
    await _peerConnection!.setLocalDescription(offer);

    try {
      await _dio.post('/api/call/offer/$_currentCallId', data: {
        'sdp': offer.sdp,
      });
    } catch (e) {
      debugPrint('[CallSession] offer error: $e');
    }
  }

  void _cleanup() {
    if (_currentCallId != null) {
      FlutterCallkitIncoming.endCall(_currentCallId!);
    }
    _ringTimeout?.cancel();
    _callSub?.cancel();
    _callSub = null;
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;
    
    _remoteStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.dispose();
    _remoteStream = null;
    
    _currentCallId = null;
    currentShopName = null;
    currentShopImageUrl = null;
    isMuted.value = false;
  }
}

enum CallState { idle, calling, connected, rejected, noAnswer, ended }
