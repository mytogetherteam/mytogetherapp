import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/animated_dots_text.dart';
import '../../data/call_session.dart';

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
  final _call = CallSession();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation1;
  late Animation<double> _pulseAnimation2;
  late Animation<double> _pulseAnimation3;

  Duration _elapsed = Duration.zero;
  late DateTime _connectedAt;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    CallScreen.isVisibleNotifier.value = true;
    _connectedAt = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseAnimation1 = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _pulseAnimation2 = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.2, 0.8, curve: Curves.easeOut)),
    );
    _pulseAnimation3 = Tween<double>(begin: 1.0, end: 2.1).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
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

    // Handle state changes
    _call.state.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    if (!mounted || _dismissing) return;
    final state = _call.state.value;

    if (state == CallState.connected) {
      // Reset timer when actually connected
      _connectedAt = DateTime.now();
      setState(() {});
    } else if (state == CallState.idle || state == CallState.ended) {
      _scheduleDismiss();
    } else if (state == CallState.rejected || state == CallState.noAnswer) {
      // Show feedback before dismissing
      setState(() {}); // Trigger rebuild to show feedback text
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
    CallScreen.isVisibleNotifier.value = false;
    _call.state.removeListener(_onCallStateChanged);
    _pulseController.dispose();
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
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Stack(
          children: [
            // Background Image
            if (widget.shopImageUrl != null)
              Positioned.fill(
                child: Image.network(
                  widget.shopImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Blur effect
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ),
            // Foreground Content
            SafeArea(
              child: ValueListenableBuilder<CallState>(
                valueListenable: _call.state,
                builder: (context, state, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        // Top Header
                        Text(
                          widget.shopName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Voice Call',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        
                        const Spacer(flex: 1),
                        
                        // Avatar / pulse animation
                        SizedBox(
                          width: 250,
                          height: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Rings
                              if (state == CallState.calling || state == CallState.ringing) ...[
                                _buildPulseRing(_pulseAnimation3, 0.1),
                                _buildPulseRing(_pulseAnimation2, 0.2),
                                _buildPulseRing(_pulseAnimation1, 0.3),
                              ],
                              // Avatar
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: widget.shopImageUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          widget.shopImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _shopInitial(),
                                        ),
                                      )
                                    : _shopInitial(),
                              ),
                            ],
                          ),
                        ),
                        
                        const Spacer(flex: 1),
                        
                        // Status / timer
                        _buildStatusLabel(state),
                        
                        const SizedBox(height: 40),
                        // Controls
                        _buildControls(state),
                        const SizedBox(height: 50),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseRing(Animation<double> animation, double opacity) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(opacity * (1.0 - (animation.value - 1.0) / 1.1).clamp(0.0, 1.0)),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.5 * (1.0 - (animation.value - 1.0) / 1.1).clamp(0.0, 1.0)),
                width: 1,
              ),
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
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 50,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusLabel(CallState state) {
    if (state == CallState.calling) {
      return AnimatedDotsText(
        baseText: 'Calling',
        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 16),
      );
    } else if (state == CallState.ringing) {
      return AnimatedDotsText(
        baseText: 'Incoming Call',
        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 16),
      );
    } else if (state == CallState.connected) {
      if (_elapsed.inSeconds == 0) {
        return AnimatedDotsText(
          baseText: 'Connecting',
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 16),
        );
      }
      return Text(
        _formatElapsed(),
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 1.5),
      );
    } else if (state == CallState.rejected) {
      return Text('Call Rejected', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16));
    } else if (state == CallState.noAnswer) {
      return Text('No Answer', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 16));
    } else if (state == CallState.ended) {
      return Text('Call Ended', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 16));
    }
    return const SizedBox(height: 24);
  }

  Widget _buildControls(CallState state) {
    if (state == CallState.ringing) {
      // Incoming call (Shop -> User)
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
            icon: PhosphorIcons.phoneX,
            label: 'Decline',
            color: Colors.red,
            onTap: () async {
              await _call.rejectIncomingCall();
              // Screen auto-dismisses via state listener
            },
          ),
          _actionButton(
            icon: PhosphorIcons.phoneCall,
            label: 'Accept',
            color: const Color(0xFF22C55E),
            onTap: () async {
              await _call.acceptIncomingCall();
            },
          ),
        ],
      );
    } else if (state == CallState.calling || state == CallState.rejected || state == CallState.noAnswer) {
      // Outgoing call (User -> Shop) or terminal state
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _actionButton(
            icon: PhosphorIcons.phoneX,
            label: 'Cancel',
            color: Colors.red,
            onTap: () async {
              await _call.endCall();
              // Screen auto-dismisses via state listener
            },
          ),
        ],
      );
    } else {
      // Connected
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute
          ValueListenableBuilder<bool>(
            valueListenable: _call.isMuted,
            builder: (_, muted, __) => _circleButton(
              icon: muted ? PhosphorIcons.microphoneSlash : PhosphorIcons.microphone,
              label: muted ? 'Unmute' : 'Mute',
              onTap: _call.toggleMute,
              bgColor: muted ? Colors.white : Colors.white.withOpacity(0.15),
              iconColor: muted ? Colors.black : Colors.white,
            ),
          ),
          // End call
          _actionButton(
            icon: PhosphorIcons.phoneSlash,
            label: 'End',
            color: Colors.red,
            size: 72,
            iconSize: 32,
            onTap: () async {
              await _call.endCall();
              // Screen auto-dismisses via state listener
            },
          ),
          // Speaker
          ValueListenableBuilder<bool>(
            valueListenable: _call.isSpeakerOn,
            builder: (_, speaker, __) => _circleButton(
              icon: speaker ? PhosphorIcons.speakerHigh : PhosphorIcons.speakerLow,
              label: speaker ? 'Speaker On' : 'Speaker Off',
              onTap: _call.toggleSpeaker,
              bgColor: speaker ? Colors.white : Colors.white.withOpacity(0.15),
              iconColor: speaker ? Colors.black : Colors.white,
            ),
          ),
        ],
      );
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 70,
    double iconSize = 30,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color iconColor,
    double size = 60,
    double iconSize = 26,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}