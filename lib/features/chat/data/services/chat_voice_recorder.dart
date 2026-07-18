import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum VoiceRecordPhase { idle, recording, locked }

class VoiceRecordingResult {
  final String path;
  final int durationSeconds;

  const VoiceRecordingResult({
    required this.path,
    required this.durationSeconds,
  });
}

/// Thin wrapper around `record` with temp-file cleanup helpers.
class ChatVoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  DateTime? _startedAt;
  String? _path;
  VoiceRecordPhase phase = VoiceRecordPhase.idle;

  final ValueNotifier<int> elapsedSeconds = ValueNotifier<int>(0);
  final ValueNotifier<VoiceRecordPhase> phaseNotifier =
      ValueNotifier<VoiceRecordPhase>(VoiceRecordPhase.idle);

  /// Gesture hints shared between the record button and the composer strip.
  final ValueNotifier<bool> cancelHint = ValueNotifier<bool>(false);
  final ValueNotifier<bool> lockHint = ValueNotifier<bool>(false);

  bool get isActive => phase != VoiceRecordPhase.idle;

  void _resetHints() {
    cancelHint.value = false;
    lockHint.value = false;
  }

  Future<bool> ensurePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<bool> start() async {
    if (isActive) return false;
    final allowed = await ensurePermission();
    if (!allowed) return false;

    final hasMic = await _recorder.hasPermission();
    if (!hasMic) return false;

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    // AAC in an M4A container keeps voice notes small while remaining broadly
    // playable. The API accepts the MPEG-4 container detected on Android.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    _path = path;
    _startedAt = DateTime.now();
    elapsedSeconds.value = 0;
    _resetHints();
    phase = VoiceRecordPhase.recording;
    phaseNotifier.value = phase;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _startedAt;
      if (started == null) return;
      elapsedSeconds.value = DateTime.now().difference(started).inSeconds;
    });
    return true;
  }

  void lock() {
    if (phase != VoiceRecordPhase.recording) return;
    phase = VoiceRecordPhase.locked;
    phaseNotifier.value = phase;
  }

  Future<VoiceRecordingResult?> stopAndFinalize() async {
    if (!isActive) return null;
    _ticker?.cancel();
    _ticker = null;

    final path = await _recorder.stop() ?? _path;
    final started = _startedAt;
    final seconds = started == null
        ? elapsedSeconds.value
        : DateTime.now().difference(started).inSeconds;

    _startedAt = null;
    _path = null;
    phase = VoiceRecordPhase.idle;
    phaseNotifier.value = phase;
    elapsedSeconds.value = 0;
    _resetHints();

    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    // Ignore accidental taps that produce almost-empty clips.
    if (seconds < 1 || await file.length() < 256) {
      await deleteFile(path);
      return null;
    }
    return VoiceRecordingResult(
      path: path,
      durationSeconds: seconds.clamp(1, 3600),
    );
  }

  Future<void> cancel() async {
    if (!isActive) return;
    _ticker?.cancel();
    _ticker = null;
    try {
      await _recorder.cancel();
    } catch (e) {
      debugPrint('[ChatVoiceRecorder.cancel] $e');
      try {
        final path = await _recorder.stop() ?? _path;
        await deleteFile(path);
      } catch (_) {}
    }
    await deleteFile(_path);
    _path = null;
    _startedAt = null;
    phase = VoiceRecordPhase.idle;
    phaseNotifier.value = phase;
    elapsedSeconds.value = 0;
    _resetHints();
  }

  static Future<void> deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
    elapsedSeconds.dispose();
    phaseNotifier.dispose();
    cancelHint.dispose();
    lockHint.dispose();
  }
}
