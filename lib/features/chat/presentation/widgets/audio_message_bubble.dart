import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_voice_player.dart';

class AudioMessageBubble extends StatefulWidget {
  final String url;
  final int durationSeconds;
  final bool isMine;
  final Color foreground;
  final Color background;

  const AudioMessageBubble({
    super.key,
    required this.url,
    required this.durationSeconds,
    required this.isMine,
    required this.foreground,
    required this.background,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  late final ChatVoicePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatVoicePlayerController();
    _controller.attach();
    if (widget.durationSeconds > 0) {
      _controller.duration.value = Duration(seconds: widget.durationSeconds);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _controller.isPlaying,
            builder: (context, playing, _) {
              return GestureDetector(
                onTap: () => _controller.toggle(
                  widget.url,
                  knownDurationSeconds: widget.durationSeconds,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.foreground.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: widget.foreground,
                    size: 22,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _controller.position,
                    _controller.duration,
                  ]),
                  builder: (context, _) {
                    final total = _controller.duration.value.inMilliseconds == 0
                        ? Duration(seconds: widget.durationSeconds)
                        : _controller.duration.value;
                    final progress = total.inMilliseconds == 0
                        ? 0.0
                        : (_controller.position.value.inMilliseconds /
                                total.inMilliseconds)
                            .clamp(0.0, 1.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor:
                                widget.foreground.withValues(alpha: 0.2),
                            valueColor:
                                AlwaysStoppedAnimation(widget.foreground),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatVoiceDuration(_controller.position.value)} / ${formatVoiceDuration(total)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: widget.foreground.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<double>(
            valueListenable: _controller.speed,
            builder: (context, speed, _) {
              return GestureDetector(
                onTap: _controller.cycleSpeed,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.foreground.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formatVoicePlaybackSpeed(speed),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.foreground,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
