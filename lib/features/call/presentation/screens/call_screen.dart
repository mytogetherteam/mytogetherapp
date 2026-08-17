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

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  final _call = CallSession();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Duration _elapsed = Duration.zero;
  late DateTime _connectedAt;

  @override
  void initState() {
    super.initState();
    CallScreen.isVisibleNotifier.value = true;
    _connectedAt = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Update elapsed time every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_call.state.value != CallState.connected) return false;
      setState(() => _elapsed = DateTime.now().difference(_connectedAt));
      return true;
    });
  }

  @override
  void dispose() {
    CallScreen.isVisibleNotifier.value = false;
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
                filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
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
                        const SizedBox(height: 60),
                      // Avatar / pulse animation
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
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
                      ),
                      const SizedBox(height: 24),
                      // Shop name
                      Text(
                        widget.shopName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Status / timer
                      if (state == CallState.calling)
                        AnimatedDotsText(
                          baseText: 'Calling',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        )
                      else
                        Text(
                          _statusLabel(state),
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                      const Spacer(),
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

  Widget _shopInitial() {
    return Center(
      child: Text(
        widget.shopName.isNotEmpty ? widget.shopName[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _statusLabel(CallState state) {
    switch (state) {
      case CallState.calling:
        return 'Calling...';
      case CallState.connected:
        return _formatElapsed();
      case CallState.rejected:
        return 'Call Rejected';
      case CallState.noAnswer:
        return 'No Answer';
      default:
        return '';
    }
  }

  Widget _buildControls(CallState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        ValueListenableBuilder<bool>(
          valueListenable: _call.isMuted,
          builder: (_, muted, __) => _circleButton(
            icon: muted ? PhosphorIcons.microphoneSlash : PhosphorIcons.microphone,
            label: muted ? 'Unmute' : 'Mute',
            onTap: _call.toggleMute,
            bgColor: muted ? Colors.white : Colors.white.withValues(alpha: 0.15),
            iconColor: muted ? Colors.red : Colors.white,
          ),
        ),
        // End call
        _circleButton(
          icon: PhosphorIcons.phoneFill,
          label: 'End',
          onTap: () async {
            await _call.endCall();
            if (context.mounted) Navigator.of(context).pop();
          },
          bgColor: Colors.red,
          iconColor: Colors.white,
          size: 70,
          iconSize: 30,
        ),
        // Speaker placeholder (styled but not wired — iOS needs AVSession)
        ValueListenableBuilder<bool>(
          valueListenable: _call.isSpeakerOn,
          builder: (_, speaker, __) => _circleButton(
            icon: speaker ? Icons.volume_up : Icons.volume_off,
            label: 'Speaker',
            onTap: () => _call.isSpeakerOn.value = !_call.isSpeakerOn.value,
            bgColor: Colors.white.withValues(alpha: 0.15),
            iconColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color iconColor,
    double size = 56,
    double iconSize = 22,
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
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}
