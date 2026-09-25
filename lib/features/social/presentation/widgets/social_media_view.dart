import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/models/post_dto.dart';

/// Full-bleed image or looping video for one social feed page.
/// Supports TikTok-style tap-to-play/pause with animated center icon,
/// a progress bar, and a mute/unmute toggle button.
class SocialMediaView extends StatefulWidget {
  final SocialPostMediaDto media;
  final bool isActive;
  final VideoPlayerController? preloadedController;
  final VoidCallback? onDoubleTapScreen;

  const SocialMediaView({
    super.key,
    required this.media,
    required this.isActive,
    this.preloadedController,
    this.onDoubleTapScreen,
  });

  @override
  State<SocialMediaView> createState() => _SocialMediaViewState();
}

class _SocialMediaViewState extends State<SocialMediaView>
    with TickerProviderStateMixin {
  VideoPlayerController? _localController;
  VideoPlayerController? get _controller =>
      widget.preloadedController ?? _localController;
  bool _initFailed = false;

  /// True when the user manually tapped to pause.
  /// Prevents auto-resume when the tab becomes active again.
  bool _userPaused = false;

  /// True when audio is muted.
  bool _muted = false;

  Timer? _tapTimer;
  DateTime? _lastTapTime;
  final List<_HeartAnim> _hearts = [];

  // ── Center icon animation ────────────────────────────────────────────
  late final AnimationController _iconAnimController;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;

  /// Which icon to flash in the center after a tap.
  bool _showPlayIcon = true;

  @override
  void initState() {
    super.initState();

    // Center tap icon: quick scale-in then fade-out
    _iconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_iconAnimController);
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(1.1), weight: 40),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.1, end: 0.9).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_iconAnimController);

    if (widget.media.isVideo) {
      if (widget.preloadedController != null) {
        widget.preloadedController!.addListener(_onControllerUpdate);
        _syncPlayback();
      } else {
        _initVideo();
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SocialMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preloadedController != widget.preloadedController) {
      oldWidget.preloadedController?.removeListener(_onControllerUpdate);
      widget.preloadedController?.addListener(_onControllerUpdate);
    }

    if (oldWidget.media.url != widget.media.url) {
      _disposeLocalVideo();
      _initFailed = false;
      _userPaused = false;
      if (widget.media.isVideo && widget.preloadedController == null) {
        _initVideo();
      }
      return;
    }
    _syncPlayback();
  }

  Future<void> _initVideo() async {
    final url = widget.media.url.trim();
    if (url.isEmpty) {
      setState(() => _initFailed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _localController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() {});
      _syncPlayback();
    } catch (_) {
      if (!mounted) return;
      setState(() => _initFailed = true);
    }
  }

  /// Sync playback with active state, respecting the user's manual pause.
  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (widget.isActive && !_userPaused) {
      if (!c.value.isPlaying) c.play();
    } else {
      if (c.value.isPlaying) c.pause();
    }

    c.setVolume(_muted ? 0.0 : 1.0);
  }

  void _disposeLocalVideo() {
    _localController?.dispose();
    _localController = null;
  }

  void _handleTapDown(TapDownDetails details) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      // Double tap detected
      _tapTimer?.cancel();
      _tapTimer = null;
      _lastTapTime = null; // Reset to allow subsequent independent taps
      
      _showHeart(details.localPosition);
      if (widget.onDoubleTapScreen != null) {
        widget.onDoubleTapScreen!();
      }
    } else {
      _lastTapTime = now;
      _tapTimer?.cancel();
      _tapTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _onTapVideo();
        }
      });
    }
  }

  void _showHeart(Offset position) {
    final heartId = UniqueKey();
    if (mounted) {
      setState(() {
        _hearts.add(_HeartAnim(heartId, position));
      });
    }
  }

  void _removeHeart(Key id) {
    if (mounted) {
      setState(() {
        _hearts.removeWhere((h) => h.id == id);
      });
    }
  }

  /// Toggle play/pause on user tap — TikTok style.
  void _onTapVideo() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (c.value.isPlaying) {
      c.pause();
      _userPaused = true;
      _showPlayIcon = false; // show pause icon (video was playing → now paused)
    } else {
      c.play();
      _userPaused = false;
      _showPlayIcon = true; // show play icon (video was paused → now playing)
    }

    _iconAnimController.forward(from: 0.0);
    setState(() {});
  }

  /// Toggle mute/unmute.
  void _toggleMute() {
    final newMuted = !_muted;
    setState(() => _muted = newMuted);
    _controller?.setVolume(newMuted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    widget.preloadedController?.removeListener(_onControllerUpdate);
    _iconAnimController.dispose();
    _disposeLocalVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // BASE LAYER: Media and Tap Detector
        GestureDetector(
          onTapDown: _handleTapDown,
          behavior: HitTestBehavior.opaque,
          child: _buildMediaBackground(),
        ),

        // OVERLAY LAYER: Controls (only if video and initialized)
        if (widget.media.isVideo && _controller != null && _controller!.value.isInitialized) ...[
          // Center tap icon (play/pause flash)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _iconAnimController,
              builder: (context, _) {
                return Opacity(
                  opacity: _iconOpacity.value,
                  child: Center(
                    child: Transform.scale(
                      scale: _iconScale.value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        child: Icon(
                          _showPlayIcon
                              ? PhosphorIcons.playFill
                              : PhosphorIcons.pauseFill,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Progress bar at the very bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _VideoProgressBar(controller: _controller!),
          ),

          // Mute/Unmute button
          Positioned(
            right: 18,
            bottom: 250,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(
                    _muted
                        ? PhosphorIcons.speakerSlashFill
                        : PhosphorIcons.speakerHighFill,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ],

        // Hearts layer
        ..._hearts.map((h) => _FloatingHeart(
              key: h.id,
              position: h.position,
              onComplete: () => _removeHeart(h.id),
            )),
      ],
    );
  }

  Widget _buildMediaBackground() {
    if (!widget.media.isVideo) {
      return _buildImage(widget.media.url);
    }

    if (_initFailed) {
      final thumb = widget.media.thumbnailUrl;
      if (thumb != null && thumb.isNotEmpty) {
        return _buildImage(thumb);
      }
      return _errorFallback();
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      final thumb = widget.media.thumbnailUrl;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumb != null && thumb.isNotEmpty)
            _buildImage(thumb)
          else
            const ColoredBox(color: Color(0xFF1A1020)),
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) => const ColoredBox(
        color: Color(0xFF1A1020),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      ),
      errorWidget: (context, url, error) => _errorFallback(),
    );
  }

  Widget _errorFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF2B1B2E), AppColors.primary, 0.3)!,
            const Color(0xFF0A0A0A),
          ],
        ),
      ),
      child: const Icon(
        PhosphorIcons.imageBroken,
        size: 72,
        color: Colors.white24,
      ),
    );
  }
}

class _HeartAnim {
  final UniqueKey id;
  final Offset position;
  _HeartAnim(this.id, this.position);
}

class _FloatingHeart extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const _FloatingHeart({
    required Key key,
    required this.position,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _moveAnim;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    ]).animate(_controller);
    
    _opacityAnim = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_controller);
    
    _moveAnim = Tween<double>(begin: 0, end: -100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 50, // center the 100x100 icon
      top: widget.position.dy - 50,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _moveAnim.value),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _opacityAnim.value,
                child: child,
              ),
            ),
          );
        },
        child: const Icon(
          PhosphorIcons.heartFill,
          color: Color(0xFFFF2D55),
          size: 100,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin progress bar that updates from the VideoPlayerController listener.
// ─────────────────────────────────────────────────────────────────────────────
class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoProgressBar({required this.controller});

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant _VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    if (!value.isInitialized) return const SizedBox.shrink();

    final position = value.position.inMilliseconds;
    final duration = value.duration.inMilliseconds;
    if (duration == 0) return const SizedBox.shrink();

    final progress = (position / duration).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 2,
              width: constraints.maxWidth,
              color: Colors.white24,
            ),
            Container(
              height: 2,
              width: constraints.maxWidth * progress,
              color: Colors.white,
            ),
          ],
        );
      },
    );
  }
}
