import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/models/post_dto.dart';

/// Full-bleed image or looping video for one social feed page.
class SocialMediaView extends StatefulWidget {
  final SocialPostMediaDto media;
  final bool isActive;

  const SocialMediaView({
    super.key,
    required this.media,
    required this.isActive,
  });

  @override
  State<SocialMediaView> createState() => _SocialMediaViewState();
}

class _SocialMediaViewState extends State<SocialMediaView> {
  VideoPlayerController? _controller;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(covariant SocialMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url) {
      _disposeVideo();
      _initFailed = false;
      if (widget.media.isVideo) {
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
    _controller = controller;
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

  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.isActive) {
      if (!c.value.isPlaying) c.play();
    } else {
      if (c.value.isPlaying) c.pause();
    }
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
