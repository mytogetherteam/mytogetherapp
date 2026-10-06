import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/network/media_url.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/home/data/models/shop_dto.dart';

/// Full-screen Messenger/Instagram-style MyDay photo viewer.
class ShopMyDayViewer extends StatefulWidget {
  final String shopName;
  final String? shopLogoUrl;
  final List<ShopMyDayDto> stories;
  final int initialIndex;

  const ShopMyDayViewer({
    super.key,
    required this.shopName,
    required this.stories,
    this.shopLogoUrl,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required String shopName,
    required List<ShopMyDayDto> stories,
    String? shopLogoUrl,
    int initialIndex = 0,
  }) {
    if (stories.isEmpty) return Future.value();
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, _, _) => ShopMyDayViewer(
          shopName: shopName,
          shopLogoUrl: shopLogoUrl,
          stories: stories,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ShopMyDayViewer> createState() => _ShopMyDayViewerState();
}

class _ShopMyDayViewerState extends State<ShopMyDayViewer>
    with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 5);

  late int _index;
  late final AnimationController _progress;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progress = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goNext();
        }
      });
    _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_index >= widget.stories.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index += 1);
    _progress
      ..duration = _storyDuration
      ..forward(from: 0);
  }

  void _goPrevious() {
    if (_index <= 0) {
      _progress.forward(from: 0);
      return;
    }
    setState(() => _index -= 1);
    _progress.forward(from: 0);
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _progress.stop();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _progress.forward();
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    final imageUrl = resolveMediaUrl(story.imageUrl);
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.of(context).maybePop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            // Tap zones
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goPrevious,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goNext,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
            // Top chrome
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i == widget.stories.length - 1 ? 0 : 4,
                            ),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (context, _) {
                                double value;
                                if (i < _index) {
                                  value = 1;
                                } else if (i > _index) {
                                  value = 0;
                                } else {
                                  value = _progress.value;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 2.5,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: resolveMediaUrl(widget.shopLogoUrl).isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl:
                                      resolveMediaUrl(widget.shopLogoUrl),
                                  fit: BoxFit.cover,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  errorWidget: (_, _, _) => Container(
                                    color: AppColors.primary,
                                    child: Center(
                                      child: Text(
                                        widget.shopName.isNotEmpty
                                            ? widget.shopName[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppColors.primary,
                                  child: Center(
                                    child: Text(
                                      widget.shopName.isNotEmpty
                                          ? widget.shopName[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _relativeTime(story.createdAt),
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
