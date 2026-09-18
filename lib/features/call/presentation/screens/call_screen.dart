import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/presentation/widgets/animated_dots_text.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/call_session.dart';

// App brand colour tokens (primary gradient: pink -> orange)
const _kBgTop       = Color(0xFFED3973); // app primary pink
const _kBgBottom    = Color(0xFF0D060A); // near-black at bottom
const _kAcceptGreen = Color(0xFF00C875);
const _kDeclineRed  = Color(0xFFE41E3F);
/// Active voice call screen shown while a call is in progress.
class CallScreen extends StatefulWidget {
  static final ValueNotifier<bool> isVisibleNotifier = ValueNotifier(false);

  final String shopName;
  final String? shopImageUrl;

  const CallScreen({
    super.key,
    required this.shopName,
    this.shopImageUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  static int _visibleCount = 0;

  final _call = CallSession();

  // Pulse rings controller (ringing / calling states)
  late AnimationController _pulseCtrl;
  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;

  Duration _elapsed = Duration.zero;
  late DateTime _connectedAt;
  bool _dismissing = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _visibleCount++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallScreen.isVisibleNotifier.value = _visibleCount > 0;
    });
    _connectedAt = DateTime.now();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _ring1 = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _ring2 = Tween<double>(begin: 1.0, end: 1.9).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.2, 0.8, curve: Curves.easeOut)),
    );
    _ring3 = Tween<double>(begin: 1.0, end: 2.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    // Update elapsed time every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_call.state.value == CallState.connected) {
        setState(() => _elapsed = DateTime.now().difference(_connectedAt));
      }
      return true;
    });

    _call.state.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    if (!mounted || _dismissing) return;
    final state = _call.state.value;
    if (state == CallState.connected) {
      _connectedAt = DateTime.now();
      setState(() {});
    } else if (state == CallState.idle || state == CallState.ended) {
      _scheduleDismiss();
    } else if (state == CallState.rejected || state == CallState.noAnswer) {
      setState(() {});
      _scheduleDismiss(delay: const Duration(seconds: 2));
    }
  }

  void _scheduleDismiss({Duration delay = Duration.zero}) {
    _dismissing = true;
    if (delay == Duration.zero) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    } else {
      Future.delayed(delay, () {
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _visibleCount--;
    if (_visibleCount < 0) _visibleCount = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallScreen.isVisibleNotifier.value = _visibleCount > 0;
    });
    _call.state.removeListener(_onCallStateChanged);
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final mins = _elapsed.inMinutes.toString().padLeft(2, '0');
    final secs = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // â”€â”€ Solid Messenger-blue status bar (visible when app is in foreground) â”€â”€
      value: const SystemUiOverlayStyle(
        statusBarColor: _kBgTop,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _kBgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBgBottom,
        body: GestureDetector(
          onVerticalDragStart: (_) => _dragOffset = 0,
          onVerticalDragUpdate: (details) {
            _dragOffset += details.primaryDelta ?? 0;
            if (_dragOffset > 100) {
              if (!_dismissing) _scheduleDismiss();
            }
          },
          onVerticalDragEnd: (details) {
            _dragOffset = 0;
            if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
              if (!_dismissing) _scheduleDismiss();
            }
          },
          child: Container(
            // Blue â†’ deep-dark gradient â€“ same as Messenger voice call
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary, _kBgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.38, 1.0],
              ),
            ),
            child: SafeArea(
              child: ValueListenableBuilder<CallState>(
                valueListenable: _call.state,
                builder: (context, state, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildTopBar(),
                        const Spacer(flex: 1),
                        _buildAvatar(state),
                        const SizedBox(height: 20),
                        _buildStatusLabel(state),
                        const Spacer(flex: 2),
                        _buildControls(state),
                        const SizedBox(height: 44),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Top bar: chevron + name â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) Navigator.of(context).pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.shopName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Voice Call',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 36), // balance
        ],
      ),
    );
  }

  // â”€â”€â”€ Avatar + pulse rings â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAvatar(CallState state) {
    final ringing = state == CallState.calling || state == CallState.ringing;
    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ringing) ...[
            _buildRing(_ring3, 0.07),
            _buildRing(_ring2, 0.13),
            _buildRing(_ring1, 0.22),
          ],
          // Avatar circle
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.38), width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  blurRadius: 44,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: widget.shopImageUrl != null
                ? ClipOval(
                    child: Image.network(
                      widget.shopImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _shopInitial(),
                    ),
                  )
                : _shopInitial(),
          ),
        ],
      ),
    );
  }

  Widget _buildRing(Animation<double> anim, double maxOpacity) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, _) {
        final t = ((anim.value - 1.0) / 1.25).clamp(0.0, 1.0);
        return Transform.scale(
          scale: anim.value,
          child: Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: maxOpacity * (1.0 - t)),
            ),
          ),
        );
      },
    );
  }

  Widget _shopInitial() {
    return Center(
      child: Text(
        widget.shopName.isNotEmpty ? widget.shopName[0].toUpperCase() : '?',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 56,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // â”€â”€â”€ Status label â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatusLabel(CallState state) {
    if (state == CallState.calling) {
      return AnimatedDotsText(
        baseText: 'Calling',
        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.78), fontSize: 16),
      );
    } else if (state == CallState.ringing) {
      return AnimatedDotsText(
        baseText: 'Incoming call',
        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.78), fontSize: 16),
      );
    } else if (state == CallState.connected) {
      if (_elapsed.inSeconds == 0) {
        return AnimatedDotsText(
          baseText: 'Connecting',
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.78), fontSize: 16),
        );
      }
      return Text(
        _formatElapsed(),
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        ),
      );
    } else if (state == CallState.rejected) {
      return Text(
        'Call Declined',
        style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 16, fontWeight: FontWeight.w500),
      );
    } else if (state == CallState.noAnswer) {
      return Text('No Answer', style: GoogleFonts.inter(color: Colors.white60, fontSize: 16));
    } else if (state == CallState.ended) {
      return Text('Call Ended', style: GoogleFonts.inter(color: Colors.white60, fontSize: 16));
    }
    return const SizedBox(height: 22);
  }

  // â”€â”€â”€ Controls â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildControls(CallState state) {
    if (state == CallState.ringing) {
      return _incomingControls();
    } else if (state == CallState.calling ||
        state == CallState.rejected ||
        state == CallState.noAnswer) {
      return _outgoingControls();
    } else {
      return _activeControls();
    }
  }

  /// Incoming â€“ large Decline (red) left, Accept (green) right like Messenger
  Widget _incomingControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 52),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _bigBtn(
            icon: PhosphorIcons.phoneX,
            label: 'Decline',
            bg: _kDeclineRed,
            onTap: () async => _call.rejectIncomingCall(),
          ),
          _bigBtn(
            icon: PhosphorIcons.phoneCall,
            label: 'Accept',
            bg: _kAcceptGreen,
            onTap: () async => _call.acceptIncomingCall(),
          ),
        ],
      ),
    );
  }

  /// Outgoing / terminal â€“ centred Cancel
  Widget _outgoingControls() {
    return _bigBtn(
      icon: PhosphorIcons.phoneX,
      label: 'Cancel',
      bg: _kDeclineRed,
      onTap: () async => _call.endCall(),
    );
  }

  /// Active call â€“ Messenger row: Mute | End | Speaker
  Widget _activeControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute
        ValueListenableBuilder<bool>(
          valueListenable: _call.isMuted,
          builder: (_, muted, _) => _circleBtn(
            icon: muted ? PhosphorIcons.microphoneSlash : PhosphorIcons.microphone,
            label: muted ? 'Unmute' : 'Mute',
            active: muted,
            onTap: _call.toggleMute,
          ),
        ),
        // End call â€“ larger + red glow
        _bigBtn(
          icon: PhosphorIcons.phoneSlash,
          label: 'End Call',
          bg: _kDeclineRed,
          size: 74,
          iconSize: 30,
          onTap: () async => _call.endCall(),
        ),
        // Speaker
        ValueListenableBuilder<bool>(
          valueListenable: _call.isSpeakerOn,
          builder: (_, speaker, _) => _circleBtn(
            icon: speaker ? PhosphorIcons.speakerHigh : PhosphorIcons.speakerNone,
            label: 'Speaker',
            active: speaker,
            onTap: _call.toggleSpeaker,
          ),
        ),
      ],
    );
  }

  // â”€â”€â”€ Button helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _bigBtn({
    required IconData icon,
    required String label,
    required Color bg,
    required VoidCallback onTap,
    double size = 72,
    double iconSize = 28,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              boxShadow: [
                BoxShadow(
                  color: bg.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    double size = 62,
    double iconSize = 25,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: active ? 0 : 0.28),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: active ? AppColors.primary : Colors.white,
              size: iconSize,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}




