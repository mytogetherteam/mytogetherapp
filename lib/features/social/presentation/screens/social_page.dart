import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import 'package:mytogetherapp/core/utils/navigation_controller.dart';
import 'package:mytogetherapp/features/wishlist/data/repositories/wishlist_repository.dart';
import '../../data/models/post_dto.dart';
import '../../data/repositories/social_posts_repository.dart';
import 'package:video_player/video_player.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import '../widgets/social_comments_sheet.dart';
import '../widgets/social_feed_status_view.dart';
import '../widgets/social_media_pager.dart';
import '../widgets/social_media_view.dart';
import 'create_social_post_page.dart';
import 'tiktok_profile_page.dart';

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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    NavigationController.instance.tabScrollToTopRequest.addListener(
      _onScrollToTopRequested,
    );
    NavigationController.instance.socialRefreshRequest.addListener(
      _onSocialRefreshRequested,
    );
    SocialPostsRepository.feedRevision.addListener(_onMineChanged);
    _loadInitial();
  }

  void _onMineChanged() {
    if (!mounted) return;
    _loadInitial();
  }

  void _onSocialRefreshRequested() {
    if (!mounted) return;
    _refreshFeed();
  }

  void _onScrollToTopRequested() {
    if (NavigationController.instance.tabScrollToTopRequest.value != 2) return;
    if (!mounted || !_pageController.hasClients) return;
    if (_currentPage == 0) {
      _refreshFeed();
    } else {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _refreshFeed() async {
    if (!mounted) return;
    AppHaptics.buttonTap();
    if (_pageController.hasClients && _currentPage != 0) {
      await _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    _refreshIndicatorKey.currentState?.show();
  }

  @override
  void dispose() {
    NavigationController.instance.tabScrollToTopRequest.removeListener(
      _onScrollToTopRequested,
    );
    NavigationController.instance.socialRefreshRequest.removeListener(
      _onSocialRefreshRequested,
    );
    SocialPostsRepository.feedRevision.removeListener(_onMineChanged);
    _pageController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _managePreload(int currentIndex) {
    // Only buffer the currently active video to minimize S3 egress bandwidth
    final toKeep = {
      currentIndex,
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

  Future<void> _loadInitial({bool isPullToRefresh = false}) async {
    if (_posts.isEmpty && !isPullToRefresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
        _error = null;
      });
      if (_pageController.hasClients && (_pageController.page ?? 0) != 0) {
        _pageController.jumpToPage(0);
      }
      _managePreload(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_posts.isEmpty) {
          _error = context.tr('social.load_failed');
        }
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
                        child: GestureDetector(
                          onDoubleTap: _refreshFeed,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
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
    if (_loading && _posts.isEmpty) {
      return SocialFeedStatusView.loading();
    }
    if (_error != null && _posts.isEmpty) {
      return SocialFeedStatusView(
        icon: PhosphorIcons.warningCircle,
        title: context.tr('social.load_failed'),
        subtitle: context.tr('social.load_failed_sub'),
        actionLabel: context.tr('social.retry'),
        onAction: () => _loadInitial(),
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
        onSecondaryAction: () => _loadInitial(),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: NavigationController.instance.currentIndex,
      builder: (context, currentIndex, child) {
        final isTabActive = currentIndex == 2; // Social tab index is 2
        final topPadding = MediaQuery.of(context).padding.top;
        return RefreshIndicator(
          key: _refreshIndicatorKey,
          color: AppColors.primary,
          backgroundColor: const Color(0xFF222228),
          displacement: 70,
          edgeOffset: topPadding + 10,
          onRefresh: () => _loadInitial(isPullToRefresh: true),
          notificationPredicate: (notification) {
            return notification.depth == 0 && _currentPage == 0;
          },
          child: PageView.builder(
            controller: _pageController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(
                parent: PageScrollPhysics(),
              ),
            ),
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
              onDeleted: () => _loadInitial(),
            ),
          ),
        );
      },
    );
  }
}

/// One saved post, opened from Saved Items.
class SocialPostViewerPage extends StatelessWidget {
  final SocialPostDto post;

  const SocialPostViewerPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _SocialFeedItem(
            post: post,
            isActive: true,
            onDeleted: () => Navigator.of(context).pop(),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical preview of one person's posts, opened from My posts.
class OwnPostsPreviewPage extends StatefulWidget {
  final List<SocialPostDto> posts;
  final int initialIndex;
  final int nextPage;
  final bool hasMore;

  /// When set, further pages come from here instead of the signed-in user's posts.
  final Future<SocialPostsFeedPage> Function(int page)? loadPage;

  const OwnPostsPreviewPage({
    super.key,
    required this.posts,
    required this.initialIndex,
    this.nextPage = 2,
    this.hasMore = false,
    this.loadPage,
  });

  @override
  State<OwnPostsPreviewPage> createState() => _OwnPostsPreviewPageState();
}

class _OwnPostsPreviewPageState extends State<OwnPostsPreviewPage> {
  late final PageController _pageController;
  late List<SocialPostDto> _posts;
  late int _index;
  late int _nextPage;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _posts = List<SocialPostDto>.of(widget.posts);
    _index = widget.initialIndex;
    _nextPage = widget.nextPage;
    _hasMore = widget.hasMore;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final result = widget.loadPage != null
          ? await widget.loadPage!(_nextPage)
          : await SocialPostsRepository.instance.fetchMine(page: _nextPage);
      if (!mounted) return;
      setState(() {
        final seen = _posts.map((post) => post.id).toSet();
        _posts.addAll(result.items.where((post) => seen.add(post.id)));
        _nextPage += 1;
        _hasMore = _nextPage <= result.totalPages && result.items.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      _loadingMore = false;
    }
  }

  void _removeAt(int index) {
    _posts.removeAt(index);
    _changed = true;
    if (_posts.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    final next = index.clamp(0, _posts.length - 1);
    if (_pageController.hasClients &&
        (_pageController.page ?? 0) >= _posts.length) {
      _pageController.jumpToPage(next);
    }
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _posts.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              if (index >= _posts.length - 2) _loadMore();
            },
            itemBuilder: (context, index) {
              final post = _posts[index];
              return _SocialFeedItem(
                key: ValueKey(post.id),
                post: post,
                isActive: index == _index,
                onDeleted: () => _removeAt(index),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                  if (_posts.isNotEmpty && !_posts[_index].isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr('social.hidden'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _SocialFeedItem extends StatefulWidget {
  final SocialPostDto post;
  final bool isActive;
  final VideoPlayerController? preloadedController;
  final VoidCallback? onDeleted;

  const _SocialFeedItem({
    super.key,
    required this.post,
    required this.isActive,
    this.preloadedController,
    this.onDeleted,
  });

  @override
  State<_SocialFeedItem> createState() => _SocialFeedItemState();
}

class _SocialFeedItemState extends State<_SocialFeedItem> {
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  late bool _saved;
  bool _saving = false;
  bool _liking = false;
  bool _reporting = false;
  bool _deleting = false;

  bool get _isOwnPost {
    final me = AuthService().currentUser?.id;
    return me != null &&
        widget.post.author.type == SocialAuthorType.user &&
        widget.post.author.id == me;
  }
  bool _captionExpanded = false;
  bool _sheetOpen = false;
  int _mediaIndex = 0;
  late PageController _horizontalController;
  final GlobalKey _likeKey = GlobalKey();
  final List<_HeartBurst> _bursts = [];
  bool _viewRecorded = false;

  void _recordViewIfNeeded() {
    if (widget.isActive && !_viewRecorded) {
      _viewRecorded = true;
      SocialPostsRepository.instance.recordView(widget.post.id);
    }
  }

  @override
  void initState() {
    super.initState();
    _horizontalController = PageController();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _saved = widget.post.savedByMe;
    WishlistRepository.instance.addListener(_onWishlistChanged);
    _recordViewIfNeeded();
  }

  void _onWishlistChanged() {
    if (!mounted || _saving) return;
    final repo = WishlistRepository.instance;
    if (!repo.knowsPost(widget.post.id)) return;
    final saved = repo.isPostSaved(widget.post.id);
    if (saved == _saved) return;
    setState(() {
      _saved = saved;
      widget.post.savedByMe = saved;
    });
  }

  @override
  void didUpdateWidget(covariant _SocialFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _liked = widget.post.likedByMe;
      _likeCount = widget.post.likeCount;
      _commentCount = widget.post.commentCount;
      _saved = widget.post.savedByMe;
      _captionExpanded = false;
      _mediaIndex = 0;
      _viewRecorded = false;
      if (_horizontalController.hasClients) {
        _horizontalController.jumpToPage(0);
      }
    }
    _recordViewIfNeeded();
  }

  @override
  void dispose() {
    WishlistRepository.instance.removeListener(_onWishlistChanged);
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

  Future<void> _toggleLike({bool burstAtButton = false}) async {
    if (_liking) return;
    _liking = true;
    try {
      await _toggleLikeBody(burstAtButton: burstAtButton);
    } finally {
      _liking = false;
    }
  }

  Future<void> _toggleLikeBody({required bool burstAtButton}) async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;
    AppHaptics.buttonTap();

    final previousLiked = _liked;
    final previousCount = _likeCount;
    setState(() {
      _liked = !_liked;
      final next = _likeCount + (_liked ? 1 : -1);
      _likeCount = next < 0 ? 0 : next;
    });
    if (_liked && burstAtButton) {
      _showHeart(_buttonCenter() ?? _feedCenter());
    }

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

  void _handleDoubleTapLike({bool showHeart = false}) {
    if (showHeart) _showHeart(_feedCenter());
    if (!_liked) {
      _toggleLike();
    }
  }

  Offset _feedCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      final size = MediaQuery.sizeOf(context);
      return Offset(size.width / 2, size.height / 2);
    }
    return box.size.center(Offset.zero);
  }

  Offset? _buttonCenter() {
    final button = _likeKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = context.findRenderObject() as RenderBox?;
    if (button == null ||
        stack == null ||
        !button.attached ||
        !button.hasSize) {
      return null;
    }
    return button.localToGlobal(
      button.size.center(Offset.zero),
      ancestor: stack,
    );
  }

  void _showHeart(Offset position) {
    final id = UniqueKey();
    setState(() => _bursts.add(_HeartBurst(id, position)));
  }

  void _removeHeart(Key id) {
    if (!mounted) return;
    setState(() => _bursts.removeWhere((burst) => burst.id == id));
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    _saving = true;
    var changed = false;
    var previousSaved = _saved;
    try {
      if (!await GuestAuthGuard.requireAccount(context)) return;
      if (!mounted) return;
      AppHaptics.buttonTap();

      previousSaved = _saved;
      changed = true;
      setState(() => _saved = !previousSaved);

      final saved =
          await WishlistRepository.instance.togglePost(widget.post.id);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        widget.post.savedByMe = saved;
      });
      AppDialog.showToast(
        context,
        context.tr(saved ? 'wishlist.saved' : 'wishlist.removed'),
      );
    } catch (_) {
      if (!mounted || !changed) return;
      setState(() => _saved = previousSaved);
      AppDialog.showToast(
        context,
        context.tr('common.favorite_failed'),
        isError: true,
      );
    } finally {
      _saving = false;
    }
  }

  Future<void> _openComments() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;
    AppHaptics.buttonTap();
    setState(() => _sheetOpen = true);
    final updatedCount = await showSocialCommentsSheet(
      context: context,
      post: widget.post,
    );
    if (!mounted) return;
    setState(() {
      _sheetOpen = false;
      _commentCount = updatedCount ?? widget.post.commentCount;
    });
  }

  Future<void> _showMoreOptions() async {
    setState(() => _sheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _MoreTile(
                  icon: _saved
                      ? PhosphorIcons.bookmarkFill
                      : PhosphorIcons.bookmark,
                  iconColor: _saved ? const Color(0xFFFFC107) : Colors.white,
                  label: context.tr(_saved ? 'social.saved' : 'social.save'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _toggleSave();
                  },
                ),
                if (_isOwnPost)
                  _MoreTile(
                    icon: PhosphorIcons.trash,
                    iconColor: Colors.red,
                    label: context.tr('social.delete_post'),
                    labelColor: Colors.red,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showDeleteConfirmation();
                    },
                  )
                else
                  _MoreTile(
                    icon: PhosphorIcons.warningCircle,
                    iconColor: Colors.red,
                    label: context.tr('social.report_post'),
                    labelColor: Colors.red,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showReportConfirmation();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  Future<void> _deletePost() async {
    if (_deleting) return;
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;
    _deleting = true;
    try {
      await SocialPostsRepository.instance.deletePost(widget.post.id);
      if (!mounted) return;
      AppDialog.showToast(context, context.tr('social.post_deleted'));
      widget.onDeleted?.call();
    } catch (_) {
      if (!mounted) return;
      AppDialog.showToast(
        context,
        context.tr('social.delete_failed'),
        isError: true,
      );
    } finally {
      _deleting = false;
    }
  }

  void _showDeleteConfirmation() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('social.delete_post'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          context.tr('social.delete_post_confirm'),
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              context.tr('common.cancel'),
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deletePost();
            },
            child: Text(
              context.tr('social.delete_post'),
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_reporting) return;
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;
    _reporting = true;
    try {
      await SocialPostsRepository.instance.reportPost(widget.post.id);
      if (!mounted) return;
      AppDialog.showToast(context, context.tr('social.report_submitted'));
    } on ReportOwnPostException {
      if (!mounted) return;
      AppDialog.showToast(
        context,
        context.tr('social.report_own'),
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      AppDialog.showToast(
        context,
        context.tr('social.report_failed'),
        isError: true,
      );
    } finally {
      _reporting = false;
    }
  }

  void _showReportConfirmation() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          context.tr('social.report_post'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          context.tr('social.report_post_confirm_desc'),
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr('common.cancel'),
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitReport();
            },
            child: Text(
              context.tr('social.report'),
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreatorProfile() async {
    AppHaptics.buttonTap();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TikTokProfilePage(
          author: widget.post.author,
          initialPost: widget.post,
        ),
      ),
    );
    if (mounted) setState(() {});
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
            SocialMediaPager(
              controller: _horizontalController,
              itemCount: media.length,
              onPageChanged: (index) {
                setState(() => _mediaIndex = index);
              },
              itemBuilder: (context, index) {
                return SocialMediaView(
                  key: ValueKey('${widget.post.id}-${media[index].id}'),
                  media: media[index],
                  isActive: widget.isActive &&
                      !_sheetOpen &&
                      _mediaIndex == index,
                  preloadedController: index == 0 ? widget.preloadedController : null,
                  onDoubleTapScreen: _handleDoubleTapLike,
                );
              },
            )
          else
            GestureDetector(
              onDoubleTap: () => _handleDoubleTapLike(showHeart: true),
              child: _TextOnlyBackdrop(caption: widget.post.caption),
            ),
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
                    authorType: widget.post.author.type,
                    onTap: _openCreatorProfile,
                  ),
                  const SizedBox(height: 20),
                  _LikeRailButton(
                    key: _likeKey,
                    postId: widget.post.id,
                    liked: _liked,
                    label: _formatCount(_likeCount),
                    onTap: () => _toggleLike(burstAtButton: true),
                  ),
                  const SizedBox(height: 14),
                  _RailAction(
                    icon: PhosphorIcons.chatCircleDotsFill,
                    label: _formatCount(_commentCount),
                    onTap: _openComments,
                  ),
                  const SizedBox(height: 14),
                  _RailAction(
                    icon: _saved
                        ? PhosphorIcons.bookmarkFill
                        : PhosphorIcons.bookmark,
                    label: context.tr(_saved ? 'social.saved' : 'social.save'),
                    iconColor:
                        _saved ? const Color(0xFFFFC107) : Colors.white,
                    onTap: _toggleSave,
                  ),
                  const SizedBox(height: 14),
                  _RailAction(
                    icon: PhosphorIcons.dotsThreeCircle,
                    label: context.tr('common.more'),
                    onTap: _showMoreOptions,
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
                  GestureDetector(
                    onTap: _openCreatorProfile,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      widget.post.author.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.post.caption.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildCaption(),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    context.relativeTime(widget.post.createdAt),
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final burst in _bursts)
            _BurstHeart(
              key: burst.id,
              position: burst.position,
              onComplete: () => _removeHeart(burst.id),
            ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    final caption = widget.post.caption;
    final body = GoogleFonts.poppins(
      color: Colors.white.withValues(alpha: 0.95),
      fontSize: 14,
      height: 1.35,
    );
    final action = GoogleFonts.poppins(
      color: Colors.white70,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final more = context.tr('social.see_more');
        final less = context.tr('social.see_less');
        final prefix = _captionPrefix(
          caption: caption,
          body: body,
          action: action,
          maxWidth: constraints.maxWidth,
          direction: Directionality.of(context),
          scaler: MediaQuery.textScalerOf(context),
          more: more,
        );
        final overflow = prefix != null;
        if (!overflow) {
          return Text(caption, style: body);
        }
        final shown = _captionExpanded ? caption : prefix;
        final text = Text.rich(
          TextSpan(
            style: body,
            children: [
              TextSpan(text: shown),
              if (!_captionExpanded) ...[
                const TextSpan(text: '… '),
                TextSpan(text: more, style: action),
              ],
            ],
          ),
          maxLines: _captionExpanded ? 8 : 2,
          overflow: TextOverflow.ellipsis,
        );
        return GestureDetector(
          onTap: () => setState(() => _captionExpanded = !_captionExpanded),
          child: _captionExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text,
                    const SizedBox(height: 4),
                    Text(less, style: action),
                  ],
                )
              : text,
        );
      },
    );
  }
}

/// The collapsed caption, cut on a word when the script uses spaces.
/// Null when the full caption already fits in two lines.
String? _captionPrefix({
  required String caption,
  required TextStyle body,
  required TextStyle action,
  required double maxWidth,
  required TextDirection direction,
  required TextScaler scaler,
  required String more,
}) {
  bool fits(String text, {required bool withMore}) {
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: text, style: body),
          if (withMore) ...[
            TextSpan(text: '… ', style: body),
            TextSpan(text: more, style: action),
          ],
        ],
      ),
      maxLines: 2,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    final overflow = painter.didExceedMaxLines;
    painter.dispose();
    return !overflow;
  }

  if (fits(caption, withMore: false)) return null;

  var low = 0;
  var high = caption.length;
  var best = 0;
  while (low <= high) {
    final mid = (low + high) >> 1;
    final slice = caption.substring(0, mid).trimRight();
    if (slice.isEmpty) {
      low = mid + 1;
      continue;
    }
    if (fits(slice, withMore: true)) {
      best = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  if (best <= 0) return '';
  var end = best;
  if (end < caption.length) {
    final raw = caption.substring(0, end);
    final atBoundary = RegExp(r'\s').hasMatch(raw[raw.length - 1]) ||
        RegExp(r'\s').hasMatch(caption[end]);
    if (!atBoundary) {
      final space = raw.lastIndexOf(RegExp(r'\s'));
      if (space > 0) end = space;
    }
  }
  final trimmed = caption.substring(0, end).trimRight();
  if (trimmed.isEmpty || !fits(trimmed, withMore: true)) {
    return caption.substring(0, best).trimRight();
  }
  return trimmed;
}

class _HeartBurst {
  final UniqueKey id;
  final Offset position;
  _HeartBurst(this.id, this.position);
}

class _BurstHeart extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const _BurstHeart({
    required Key key,
    required this.position,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<_BurstHeart> createState() => _BurstHeartState();
}

class _BurstHeartState extends State<_BurstHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(tween: ConstantTween(1.15), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 30,
      ),
    ]).animate(_controller);
    _rise = Tween<double>(begin: 0, end: -72).animate(
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
      left: widget.position.dx - 42,
      top: widget.position.dy - 42,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _rise.value),
              child: Opacity(
                opacity: _opacity.value,
                child: Transform.scale(scale: _scale.value, child: child),
              ),
            );
          },
          child: const Icon(
            PhosphorIcons.heartFill,
            color: Color(0xFFFF2D55),
            size: 84,
          ),
        ),
      ),
    );
  }
}

class _LikeRailButton extends StatefulWidget {
  final int postId;
  final bool liked;
  final String label;
  final VoidCallback onTap;

  const _LikeRailButton({
    super.key,
    required this.postId,
    required this.liked,
    required this.label,
    required this.onTap,
  });

  @override
  State<_LikeRailButton> createState() => _LikeRailButtonState();
}

class _LikeRailButtonState extends State<_LikeRailButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 0.92)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _LikeRailButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId == widget.postId && oldWidget.liked != widget.liked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.liked ? const Color(0xFFFF2D55) : Colors.white;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              PhosphorIcons.heartFill,
              color: color,
              size: 34,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color labelColor;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          color: labelColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
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
  final SocialAuthorType authorType;
  final VoidCallback? onTap;

  const _CreatorAvatar({
    this.avatarUrl,
    required this.authorName,
    this.authorType = SocialAuthorType.user,
    this.onTap,
  });

  /// Curated luxury gradient palette for personal accounts
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFFFF5E62), Color(0xFFFF9966)], // Sunset Coral
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Deep Violet
    [Color(0xFF00C6FF), Color(0xFF0072FF)], // Electric Ocean
    [Color(0xFFF857A6), Color(0xFFFF5858)], // Neon Rose
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Mint Emerald
    [Color(0xFFFF8008), Color(0xFFFFC837)], // Warm Amber
    [Color(0xFF654EA3), Color(0xFFEAAFC8)], // Lavender Bloom
    [Color(0xFF1D976C), Color(0xFF93F9B9)], // Lush Jade
    [Color(0xFFFC5C7D), Color(0xFF6A82FB)], // Velvet Twilight
    [Color(0xFF2193B0), Color(0xFF6DD5ED)], // Arctic Blue
    [Color(0xFFDA22FF), Color(0xFF9733EE)], // Cyber Magenta
    [Color(0xFFFA709A), Color(0xFFFEE140)], // Peach Sunrise
  ];

  static LinearGradient _getGradientForName(String name) {
    if (name.isEmpty) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      );
    }
    int hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final colors = _avatarGradients[hash % _avatarGradients.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  static String _extractInitials(String rawName) {
    final clean = rawName.replaceAll(RegExp(r'^[@\s\-_.]+'), '').trim();
    if (clean.isEmpty) return 'U';

    final words = clean.split(RegExp(r'[\s\-_\.]+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      final f = words[0].characters.first.toUpperCase();
      final s = words[1].characters.first.toUpperCase();
      if (RegExp(r'^[A-Z0-9]').hasMatch(f) && RegExp(r'^[A-Z0-9]').hasMatch(s)) {
        return '$f$s';
      }
      return f;
    }

    return clean.characters.first.toUpperCase();
  }

  Widget _buildUserInitialAvatar() {
    final initials = _extractInitials(authorName);
    final gradient = _getGradientForName(authorName);
    final isTwoLetters = initials.length > 1;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Glass specular depth overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Centered crisp typography
          Center(
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isTwoLetters ? 15 : 19,
                fontWeight: FontWeight.w700,
                letterSpacing: isTwoLetters ? -0.5 : 0,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    final isSuperAdmin = authorType == SocialAuthorType.admin ||
        authorName.toLowerCase().contains('super admin');
    if (isSuperAdmin) {
      return Container(
        decoration: const BoxDecoration(
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

    if (authorType == SocialAuthorType.shop) {
      return Container(
        decoration: const BoxDecoration(
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

    return _buildUserInitialAvatar();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }
    return avatar;
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

