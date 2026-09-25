import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import 'package:mytogetherapp/core/utils/navigation_controller.dart';
import '../../data/models/post_dto.dart';
import '../../data/repositories/social_posts_repository.dart';
import 'package:video_player/video_player.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../widgets/social_comments_sheet.dart';
import '../widgets/social_feed_status_view.dart';
import '../widgets/social_media_view.dart';
import 'create_social_post_page.dart';

/// Full-screen vertical social feed (For You from API).
class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  late final PageController _pageController;

  int _currentPage = 0;

  final List<SocialPostDto> _posts = [];
  int _nextPage = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    NavigationController.instance.tabScrollToTopRequest.addListener(
      _onScrollToTopRequested,
    );
    _loadInitial();
  }

  void _onScrollToTopRequested() {
    if (NavigationController.instance.tabScrollToTopRequest.value != 2) return;
    if (!mounted || !_pageController.hasClients) return;
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    NavigationController.instance.tabScrollToTopRequest.removeListener(
      _onScrollToTopRequested,
    );
    _pageController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _managePreload(int currentIndex) {
    final toKeep = {
      currentIndex - 1,
      currentIndex,
      currentIndex + 1,
      currentIndex + 2
    };

    _videoControllers.removeWhere((index, controller) {
      if (!toKeep.contains(index)) {
        controller.dispose();
        return true;
      }
      return false;
    });

    for (var i in toKeep) {
      if (i >= 0 && i < _posts.length && !_videoControllers.containsKey(i)) {
        final post = _posts[i];
        if (post.media.isNotEmpty) {
          final firstMedia = post.media.first;
          if (firstMedia.isVideo) {
            final url = firstMedia.url.trim();
            if (url.isNotEmpty) {
              final controller = VideoPlayerController.networkUrl(Uri.parse(url));
              _videoControllers[i] = controller;
              controller.initialize().then((_) {
                controller.setLooping(true);
              }).catchError((_) {});
            }
          } else {
            final url = firstMedia.url.trim();
            if (url.isNotEmpty) {
              String imageUrl = url.startsWith('http') ? url : '${ApiClient.baseUrl}/$url';
              precacheImage(CachedNetworkImageProvider(imageUrl), context);
            }
          }
        }
      }
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await SocialPostsRepository.instance.fetchFeed(page: 1);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(page.items);
        _nextPage = 2;
        _totalPages = page.totalPages;
        _loading = false;
        _currentPage = 0;
      });
      _managePreload(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr('social.load_failed');
      });
    }
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (_loadingMore || _nextPage > _totalPages) return;
    if (index < _posts.length - 2) return;
    setState(() => _loadingMore = true);
    try {
      final page =
          await SocialPostsRepository.instance.fetchFeed(page: _nextPage);
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.items);
        _nextPage += 1;
        _totalPages = page.totalPages;
        _loadingMore = false;
      });
      _managePreload(_currentPage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _openCreate() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;
    AppHaptics.buttonTap();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateSocialPostPage()),
    );
    if (created == true && mounted) {
      await _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Stack(
        fit: StackFit.expand,
        children: [
          _buildForYouBody(),
          // ── Top header bar ─────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    children: [
                      // ── Top Left Logo ────────────────────────────────────────
                      Positioned(
                        left: 4,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/app_icon_small.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Centre title
                      Center(
                        child: Text(
                          context.tr('social.for_you'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ── "+ Post" button top-right ──────────────────────
                      Positioned(
                        right: 0,
                        top: 5,
                        bottom: 5,
                        child: GestureDetector(
                          onTap: _openCreate,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(PhosphorIcons.plusBold,
                                        size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('social.create_post'),
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildForYouBody() {
    if (_loading) {
      return SocialFeedStatusView.loading();
    }
    if (_error != null) {
      return SocialFeedStatusView(
        icon: PhosphorIcons.warningCircle,
        title: context.tr('social.load_failed'),
        subtitle: context.tr('social.load_failed_sub'),
        actionLabel: context.tr('social.retry'),
        onAction: _loadInitial,
        showPreviewSlots: false,
      );
    }
    if (_posts.isEmpty) {
      return SocialFeedStatusView(
        icon: PhosphorIcons.playFill,
        title: context.tr('social.empty_feed_title'),
        subtitle: context.tr('social.empty_feed_sub'),
        actionLabel: context.tr('social.create_post'),
        onAction: _openCreate,
        secondaryActionLabel: context.tr('social.retry'),
        onSecondaryAction: _loadInitial,
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: NavigationController.instance.currentIndex,
      builder: (context, currentIndex, child) {
        final isTabActive = currentIndex == 2; // Social tab index is 2
        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          allowImplicitScrolling: true,
          itemCount: _posts.length,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
            _managePreload(index);
            _loadMoreIfNeeded(index);
          },
          itemBuilder: (context, index) => _SocialFeedItem(
            post: _posts[index],
            isActive: isTabActive && index == _currentPage,
            preloadedController: _videoControllers[index],
          ),
        );
      },
    );
  }
}

class _SocialFeedItem extends StatefulWidget {
  final SocialPostDto post;
  final bool isActive;
  final VideoPlayerController? preloadedController;

  const _SocialFeedItem({
    required this.post,
    required this.isActive,
    this.preloadedController,
  });

  @override
  State<_SocialFeedItem> createState() => _SocialFeedItemState();
}

class _SocialFeedItemState extends State<_SocialFeedItem> {
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  int _mediaIndex = 0;
  late PageController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = PageController();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
  }

  @override
  void didUpdateWidget(covariant _SocialFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _liked = widget.post.likedByMe;
      _likeCount = widget.post.likeCount;
      _commentCount = widget.post.commentCount;
      _mediaIndex = 0;
      if (_horizontalController.hasClients) {
        _horizontalController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  Future<void> _toggleLike() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    AppHaptics.buttonTap();

    final previousLiked = _liked;
    final previousCount = _likeCount;
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });

    try {
      final result =
          await SocialPostsRepository.instance.toggleLike(widget.post.id);
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
        widget.post.likedByMe = result.liked;
        widget.post.likeCount = result.likeCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likeCount = previousCount;
      });
    }
  }

  void _handleDoubleTapLike() {
    if (!_liked) {
      _toggleLike();
    }
  }

  Future<void> _openComments() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;
    AppHaptics.buttonTap();
    final updatedCount = await showSocialCommentsSheet(
      context: context,
      post: widget.post,
    );
    if (!mounted) return;
    setState(() {
      _commentCount = updatedCount ?? widget.post.commentCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.post.media;

    return Container(
      color: const Color(0xFF121212),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media.isNotEmpty)
            PageView.builder(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              onPageChanged: (index) {
                setState(() => _mediaIndex = index);
              },
              itemBuilder: (context, index) {
                return SocialMediaView(
                  key: ValueKey('${widget.post.id}-${media[index].id}'),
                  media: media[index],
                  isActive: widget.isActive && _mediaIndex == index,
                  preloadedController: index == 0 ? widget.preloadedController : null,
                  onDoubleTapScreen: _handleDoubleTapLike,
                );
              },
            )
          else
            _TextOnlyBackdrop(caption: widget.post.caption),
          // IgnorePointer is REQUIRED — BoxDecoration.hitTest() returns true
          // for every point inside the rect, so without IgnorePointer this
          // gradient swallows all taps before they reach SocialMediaView.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.18, 0.55, 1.0],
                ),
              ),
            ),
          ),
          if (media.length > 1) ...[
            Positioned(
              top: MediaQuery.paddingOf(context).top + 54,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_mediaIndex + 1}/${media.length}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 58,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(media.length, (i) {
                  return GestureDetector(
                    onTap: () {
                      _horizontalController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: i == _mediaIndex ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _mediaIndex ? Colors.white : Colors.white38,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
          Positioned(
            right: 10,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _CreatorAvatar(
                    avatarUrl: widget.post.author.avatarUrl,
                    authorName: widget.post.author.displayName,
                  ),
                  const SizedBox(height: 20),
                  _RailAction(
                    icon: PhosphorIcons.heartFill,
                    label: _formatCount(_likeCount),
                    iconColor: _liked
                        ? const Color(0xFFFF2D55)
                        : Colors.white,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(height: 18),
                  _RailAction(
                    icon: PhosphorIcons.chatCircleDotsFill,
                    label: _formatCount(_commentCount),
                    onTap: _openComments,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 88,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.author.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.post.caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.post.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextOnlyBackdrop extends StatelessWidget {
  final String caption;

  const _TextOnlyBackdrop({required this.caption});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2B1B2E), AppColors.primary, 0.45)!,
            const Color(0xFF12080F),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            caption.isEmpty ? 'MyTogether' : caption,
            textAlign: TextAlign.center,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String authorName;

  const _CreatorAvatar({
    this.avatarUrl,
    required this.authorName,
  });

  Widget _buildDefaultAvatar() {
    if (authorName.toLowerCase().contains('super admin')) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Image.asset(
          'assets/images/super_admin.png',
          cacheWidth: 100,
          cacheHeight: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/logo_3d.png',
            cacheWidth: 100,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Image.asset(
          'assets/images/logo_3d.png',
          cacheWidth: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  const _RailAction({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 34,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                    color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

