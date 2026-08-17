import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/profile_avatar_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import 'package:mytogetherapp/core/utils/navigation_controller.dart';
import '../../data/models/post_dto.dart';
import '../../data/repositories/social_posts_repository.dart';
import '../widgets/social_comments_sheet.dart';
import '../widgets/social_feed_status_view.dart';
import '../widgets/social_media_view.dart';

/// Full-screen vertical social feed (For You from API).
///
/// v1: consume only — no create, no follow.
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
    super.dispose();
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildForYouBody(),
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
                    alignment: Alignment.center,
                    children: [
                      Text(
                        context.tr('social.for_you'),
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
                      const Align(
                        alignment: Alignment.centerRight,
                        child: ProfileAvatarButton(size: 32),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
        actionLabel: context.tr('social.retry'),
        onAction: _loadInitial,
        secondaryActionLabel: context.tr('social.browse_food'),
        onSecondaryAction: () => NavigationController.instance.goToFoodTab(),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      allowImplicitScrolling: true,
      itemCount: _posts.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        _loadMoreIfNeeded(index);
      },
      itemBuilder: (context, index) => _SocialFeedItem(
        post: _posts[index],
        isActive: index == _currentPage,
      ),
    );
  }
}

class _SocialFeedItem extends StatefulWidget {
  final SocialPostDto post;
  final bool isActive;

  const _SocialFeedItem({
    required this.post,
    required this.isActive,
  });

  @override
  State<_SocialFeedItem> createState() => _SocialFeedItemState();
}

class _SocialFeedItemState extends State<_SocialFeedItem> {
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  int _mediaIndex = 0;

  @override
  void initState() {
    super.initState();
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
    }
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
    final activeMedia =
        media.isEmpty ? null : media[_mediaIndex.clamp(0, media.length - 1)];

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (activeMedia != null)
            SocialMediaView(
              key: ValueKey('${widget.post.id}-${activeMedia.id}'),
              media: activeMedia,
              isActive: widget.isActive,
            )
          else
            const ColoredBox(color: Color(0xFF1A1020)),
          const DecoratedBox(
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
          if (media.length > 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(media.length, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _mediaIndex = i),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _mediaIndex ? Colors.white : Colors.white38,
                      ),
                    ),
                  );
                }),
              ),
            ),
          Positioned(
            right: 10,
            bottom: 24,
            child: Column(
              children: [
                _CreatorAvatar(avatarUrl: widget.post.author.avatarUrl),
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
          Positioned(
            left: 14,
            right: 88,
            bottom: 28,
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
        ],
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _CreatorAvatar({this.avatarUrl});

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
                errorWidget: (context, url, error) => ColoredBox(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  child: const Icon(
                    PhosphorIcons.user,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              )
            : ColoredBox(
                color: AppColors.primary.withValues(alpha: 0.5),
                child: const Icon(
                  PhosphorIcons.user,
                  color: Colors.white,
                  size: 22,
                ),
              ),
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
