import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_voice_player.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_voice_recorder.dart';

typedef VoiceRecordSendCallback = Future<void> Function(
  VoiceRecordingResult result,
);

/// Messenger-style hold-to-record control with slide-to-cancel / slide-to-lock.
///
/// While recording, the composer should swap its text field for a
/// [VoiceRecordingStrip] (listen to `recorder.phaseNotifier`).
class VoiceRecordButton extends StatefulWidget {
  final ChatVoiceRecorder recorder;
  final bool enabled;
  final bool isBusy;
  final VoiceRecordSendCallback onSend;
  final VoidCallback? onPermissionDenied;

  const VoiceRecordButton({
    super.key,
    required this.recorder,
    required this.onSend,
    this.enabled = true,
    this.isBusy = false,
    this.onPermissionDenied,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  Offset _start = Offset.zero;

  bool get _cancelHint => widget.recorder.cancelHint.value;
  bool get _lockHint => widget.recorder.lockHint.value;

  Future<void> _begin(Offset globalPosition) async {
    if (!widget.enabled || widget.isBusy || widget.recorder.isActive) return;
    // Messenger hides the keyboard while recording.
    FocusManager.instance.primaryFocus?.unfocus();
    final started = await widget.recorder.start();
    if (!started) {
      widget.onPermissionDenied?.call();
      return;
    }
    HapticFeedback.lightImpact();
    _start = globalPosition;
  }

  void _update(Offset globalPosition) {
    if (!widget.recorder.isActive) return;
    final dx = globalPosition.dx - _start.dx;
    final dy = globalPosition.dy - _start.dy;
    widget.recorder.cancelHint.value = dx < -56;
    widget.recorder.lockHint.value = dy < -56 && dx >= -56;
  }

  Future<void> _end() async {
    if (!widget.recorder.isActive) return;

    if (_cancelHint) {
      await widget.recorder.cancel();
      return;
    }

    if (_lockHint && widget.recorder.phase == VoiceRecordPhase.recording) {
      widget.recorder.lock();
      widget.recorder.lockHint.value = false;
      return;
    }

    if (widget.recorder.phase == VoiceRecordPhase.locked) {
      return;
    }

    final result = await widget.recorder.stopAndFinalize();
    if (result != null) {
      await widget.onSend(result);
    }
  }

  Future<void> _sendLocked() async {
    final result = await widget.recorder.stopAndFinalize();
    if (result != null) {
      await widget.onSend(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.recorder.phaseNotifier,
        widget.recorder.cancelHint,
      ]),
      builder: (context, _) {
        final phase = widget.recorder.phase;
        final recording = phase != VoiceRecordPhase.idle;
        final locked = phase == VoiceRecordPhase.locked;
        final cancelHint = _cancelHint;

        return Listener(
          onPointerDown: (event) {
            if (locked) {
              if (!widget.isBusy) _sendLocked();
              return;
            }
            _begin(event.position);
          },
          onPointerMove: (event) {
            if (locked) return;
            _update(event.position);
          },
          onPointerUp: (_) {
            if (locked) return;
            _end();
          },
          onPointerCancel: (_) {
            if (locked) return;
            widget.recorder.cancel();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: recording ? 56 : 44,
            height: recording ? 56 : 44,
            decoration: BoxDecoration(
              gradient: (!widget.enabled || widget.isBusy)
                  ? null
                  : (cancelHint
                      ? const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        )
                      : AppColors.primaryGradient),
              color: (!widget.enabled || widget.isBusy)
                  ? Colors.grey[300]
                  : null,
              shape: BoxShape.circle,
              boxShadow: recording
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              locked
                  ? Icons.send_rounded
                  : (cancelHint
                      ? Icons.delete_outline_rounded
                      : Icons.mic_rounded),
              color: Colors.white,
              size: recording ? 24 : 22,
            ),
          ),
        );
      },
    );
  }
}

/// Replaces the composer text field while a voice note is being recorded,
/// matching Messenger (timer + status where the text box was).
class VoiceRecordingStrip extends StatelessWidget {
  final ChatVoiceRecorder recorder;
  final bool isBusy;
  final VoiceRecordSendCallback onSend;

  const VoiceRecordingStrip({
    super.key,
    required this.recorder,
    required this.onSend,
    this.isBusy = false,
  });

  Future<void> _sendLocked() async {
    final result = await recorder.stopAndFinalize();
    if (result != null) {
      await onSend(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        recorder.phaseNotifier,
        recorder.elapsedSeconds,
        recorder.cancelHint,
        recorder.lockHint,
      ]),
      builder: (context, _) {
        final locked = recorder.phase == VoiceRecordPhase.locked;
        final cancelHint = recorder.cancelHint.value;
        final lockHint = recorder.lockHint.value;
        final elapsed = formatVoiceDuration(
          Duration(seconds: recorder.elapsedSeconds.value),
        );

        final accent =
            cancelHint ? const Color(0xFFEF4444) : AppColors.primary;
        final status = locked
            ? 'Recording · $elapsed'
            : (cancelHint
                ? 'Release to cancel'
                : (lockHint
                    ? 'Release to lock'
                    : 'Slide left to cancel · $elapsed'));

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: cancelHint
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                locked
                    ? Icons.lock_rounded
                    : (cancelHint
                        ? Icons.delete_outline_rounded
                        : Icons.mic_rounded),
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              if (locked) ...[
                GestureDetector(
                  onTap: () => recorder.cancel(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isBusy ? null : _sendLocked,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Send',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
