import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/features/call/data/call_session.dart';
import 'package:mytogetherapp/features/call/presentation/screens/call_screen.dart';
import 'package:mytogetherapp/app.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'dart:async';

class FloatingCallBanner extends StatefulWidget {
  const FloatingCallBanner({super.key});

  @override
  State<FloatingCallBanner> createState() => _FloatingCallBannerState();
}

class _FloatingCallBannerState extends State<FloatingCallBanner> with SingleTickerProviderStateMixin {
  late AnimationController _iconPulseController;
  late Animation<double> _iconPulseAnimation;

  @override
  void initState() {
    super.initState();
    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _iconPulseAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _iconPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallState>(
      valueListenable: CallSession().state,
      builder: (context, state, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: CallScreen.isVisibleNotifier,
          builder: (context, isVisible, child) {
            if (isVisible || state == CallState.idle || state == CallState.ended) {
              return const SizedBox.shrink();
            }

            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  final nav = App.navigatorKey.currentState;
                  if (nav != null) {
                    nav.push(
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          shopName: CallSession().currentShopName ?? 'Unknown',
                          shopImageUrl: CallSession().currentShopImageUrl,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  color: const Color(0xFF22C55E), // Messenger Green
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ScaleTransition(
                            scale: state == CallState.connected ? const AlwaysStoppedAnimation(1.0) : _iconPulseAnimation,
                            child: const Icon(PhosphorIcons.phoneCallFill, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CallSession().currentShopName ?? 'Ongoing Call',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (state == CallState.connected)
                                  _TimerText()
                                else if (state == CallState.calling || state == CallState.ringing)
                                  Text(
                                    'Ringing...',
                                    style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(PhosphorIcons.caretRight, color: Colors.white70, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimerText extends StatefulWidget {
  @override
  State<_TimerText> createState() => _TimerTextState();
}

class _TimerTextState extends State<_TimerText> {
  late final Timer _timer;
  Duration _elapsed = Duration.zero;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = _elapsed.inMinutes.toString().padLeft(2, '0');
    final secs = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      'Tap to return • $mins:$secs',
      style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
    );
  }
}
