import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Cycles Messenger-style playback speeds: 1x → 1.5x → 2x → 1x.
double nextVoicePlaybackSpeed(double current) {
  if (current < 1.25) return 1.5;
  if (current < 1.75) return 2.0;
  return 1.0;
}

String formatVoicePlaybackSpeed(double speed) {
  if (speed == 1.0) return '1x';
  if (speed == 1.5) return '1.5x';
  if (speed == 2.0) return '2x';
  return '${speed}x';
}

String formatVoiceDuration(Duration value) {
  final total = value.inSeconds.clamp(0, 359999);
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Ensures only one chat voice bubble plays at a time.
class ChatVoicePlaybackCoordinator {
  static final ChatVoicePlaybackCoordinator instance =
      ChatVoicePlaybackCoordinator._();
  ChatVoicePlaybackCoordinator._();

  VoidCallback? _activeStopper;

  void claim(VoidCallback stopPlayback) {
    if (_activeStopper == stopPlayback) return;
    final previous = _activeStopper;
    _activeStopper = stopPlayback;
    previous?.call();
  }

  void release(VoidCallback stopPlayback) {
    if (_activeStopper == stopPlayback) {
      _activeStopper = null;
    }
  }
}

/// Force media/speaker routing so playback is audible after mic recording
/// (Android often stays in communication/earpiece mode otherwise).
AudioContext _voicePlaybackAudioContext() {
  return AudioContextConfig(
    route: AudioContextConfigRoute.speaker,
    focus: AudioContextConfigFocus.gain,
  ).build();
}

class ChatVoicePlayerController {
  ChatVoicePlayerController();

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<double> speed = ValueNotifier<double>(1.0);

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<Object>? _errorSub;
  String? _loadedUrl;

  Future<void> attach() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1.0);
    try {
      await _player.setAudioContext(_voicePlaybackAudioContext());
    } catch (e) {
      debugPrint('[ChatVoicePlayerController.audioContext] $e');
    }
    _posSub = _player.onPositionChanged.listen((value) {
      position.value = value;
    });
    _durSub = _player.onDurationChanged.listen((value) {
      if (value > Duration.zero) duration.value = value;
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      isPlaying.value = false;
      position.value = Duration.zero;
      ChatVoicePlaybackCoordinator.instance.release(_stopForCoordinator);
    });
    _errorSub = _player.onLog.listen((msg) {
      debugPrint('[ChatVoicePlayerController.log] $msg');
    });
  }

  Future<void> toggle(String url, {int? knownDurationSeconds}) async {
    if (url.isEmpty) {
      debugPrint('[ChatVoicePlayerController] empty url');
      return;
    }
    if (knownDurationSeconds != null &&
        knownDurationSeconds > 0 &&
        duration.value == Duration.zero) {
      duration.value = Duration(seconds: knownDurationSeconds);
    }

    if (isPlaying.value && _loadedUrl == url) {
      await pause();
      return;
    }

    ChatVoicePlaybackCoordinator.instance.claim(_stopForCoordinator);

    try {
      // Re-assert speaker/media route in case recording changed the session.
      await _player.setAudioContext(_voicePlaybackAudioContext());
      await _player.setVolume(1.0);

      if (_loadedUrl != url) {
        await _player.stop();
        debugPrint('[ChatVoicePlayerController] play $url');
        await _player.setSourceUrl(url);
        _loadedUrl = url;
        position.value = Duration.zero;
      }

      await _player.setPlaybackRate(speed.value);
      await _player.resume();
      isPlaying.value = true;
    } catch (e) {
      debugPrint('[ChatVoicePlayerController.toggle] $e');
      isPlaying.value = false;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    isPlaying.value = false;
  }

  Future<void> seek(Duration value) async {
    await _player.seek(value);
    position.value = value;
  }

  Future<void> cycleSpeed() async {
    final next = nextVoicePlaybackSpeed(speed.value);
    speed.value = next;
    await _player.setPlaybackRate(next);
  }

  void _stopForCoordinator() {
    unawaited(_forceStop());
  }

  Future<void> _forceStop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[ChatVoicePlayerController.stop] $e');
    }
    isPlaying.value = false;
    position.value = Duration.zero;
  }

  Future<void> dispose() async {
    ChatVoicePlaybackCoordinator.instance.release(_stopForCoordinator);
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _completeSub?.cancel();
    await _errorSub?.cancel();
    await _player.dispose();
    isPlaying.dispose();
    position.dispose();
    duration.dispose();
    speed.dispose();
  }
}
