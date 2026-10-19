import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_splash_factory.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../data/models/post_dto.dart';
import '../../data/repositories/social_posts_repository.dart';
import 'social_page.dart';

/// TikTok-style creator profile detail page.
/// Exclusively available for SuperAdmin and Shop accounts (personal accounts not shown).
/// Displays creator information, real stats (posts count, total likes),
/// "Go to Restaurant" action button with full multi-language support,
/// and their posted videos & images in a 3-column Grid layout.
class TikTokProfilePage extends StatefulWidget {
  final SocialPostAuthorDto author;
  final SocialPostDto? initialPost;
  final bool initialFollowing;
  final void Function(bool following)? onFollowChanged;

  const TikTokProfilePage({
    super.key,
    required this.author,
    this.initialPost,
    this.initialFollowing = false,
    this.onFollowChanged,
  });

  @override
  State<TikTokProfilePage> createState() => _TikTokProfilePageState();
}

class _TikTokProfilePageState extends State<TikTokProfilePage> {
  final List<SocialPostDto> _posts = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _totalElements = 0;
  int _totalLikes = 0;
  int _totalViews = 0;
  int _generation = 0;
  late bool _followed;
  int _followerCount = 0;
  bool _followBusy = false;
  int _followEpoch = 0;

  bool get _isShop => widget.author.type == SocialAuthorType.shop;
  bool get _isAdmin => widget.author.type == SocialAuthorType.admin;
  bool get _canFollow {
    if (_isAdmin || widget.author.id <= 0) return false;
    final me = AuthService().currentUser?.id;
    return !(widget.author.type == SocialAuthorType.user &&
        me != null &&
        me == widget.author.id);
  }

  Future<void> _loadFollow() async {
    if (!_canFollow && _isAdmin) return;
    if (widget.author.id <= 0) return;
    if (widget.author.type == SocialAuthorType.admin) return;
    final epoch = _followEpoch;
    try {
      final status = await SocialPostsRepository.instance.followStatus(
        userId: widget.author.type == SocialAuthorType.user
            ? widget.author.id
            : null,
        shopId: _isShop ? widget.author.id : null,
      );
      if (!mounted || epoch != _followEpoch) return;
      setState(() {
        _followed = status.following;
        _followerCount = status.followerCount;
      });
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || !_canFollow) return;
    if (!await GuestAuthGuard.requireAccount(context)) return;
    _followEpoch += 1;
    setState(() => _followBusy = true);
    try {
      final result = await SocialPostsRepository.instance.toggleFollow(
        userId: widget.author.type == SocialAuthorType.user
            ? widget.author.id
            : null,
        shopId: _isShop ? widget.author.id : null,
      );
      if (!mounted) return;
      setState(() {
        _followed = result.following;
        _followerCount = result.followerCount;
      });
      widget.onFollowChanged?.call(result.following);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('social.follow_failed'))),
      );
      await _loadFollow();
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _followed = widget.initialFollowing;
    if (widget.initialPost != null && _isMatchingAuthor(widget.initialPost!)) {
      _totalElements = 1;
      _totalLikes = widget.initialPost!.likeCount;
      _totalViews = widget.initialPost!.viewCount;
    }
    _scrollController.addListener(_onScroll);
    _loadPosts(reset: true);
    _loadFollow();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 320) {
      _loadPosts();
    }
  }

  bool _isMatchingAuthor(SocialPostDto post) {
    if (widget.author.type == SocialAuthorType.admin) {
      return post.author.type == SocialAuthorType.admin &&
          (widget.author.id <= 0 || post.author.id == widget.author.id);
    }
    return post.author.type == widget.author.type &&
        post.author.id == widget.author.id;
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (reset) {
      _generation += 1;
      _page = 1;
      _totalPages = 1;
    } else if (_loading || _loadingMore || _page > _totalPages) {
      return;
    }

    final currentGen = _generation;
    final pageToLoad = _page;

    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await SocialPostsRepository.instance.fetchByAuthor(
        type: widget.author.type,
        id: widget.author.id,
        page: pageToLoad,
      );

      if (!mounted || currentGen != _generation) return;

      setState(() {
        if (reset) {
          _posts.clear();
          if (widget.initialPost != null &&
              _isMatchingAuthor(widget.initialPost!) &&
              result.items.every((p) => p.id != widget.initialPost!.id)) {
            _posts.add(widget.initialPost!);
          }
        }
        final seen = _posts.map((p) => p.id).toSet();
        for (final item in result.items) {
          if (_isMatchingAuthor(item) && seen.add(item.id)) {
            _posts.add(item);
          }
        }

        _totalPages = result.totalPages;
        _totalElements = (widget.author.type == SocialAuthorType.admin)
            ? _posts.length
            : (result.totalElements > 0 ? result.totalElements : _posts.length);
        _totalLikes = _posts.fold<int>(0, (sum, p) => sum + p.likeCount);
        _totalViews = _posts.fold<int>(0, (sum, p) => sum + p.viewCount);
        _page = pageToLoad + 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || currentGen != _generation) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset && _posts.isEmpty) {
          if (widget.initialPost != null &&
              _isMatchingAuthor(widget.initialPost!)) {
            _posts.add(widget.initialPost!);
            _totalElements = 1;
            _totalLikes = widget.initialPost!.likeCount;
            _totalViews = widget.initialPost!.viewCount;
          } else {
            _error = context.tr('social.my_posts_load_failed');
          }
        }
      });
    }
  }

  void _openPreview(int index) async {
    AppHaptics.buttonTap();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OwnPostsPreviewPage(
          posts: List<SocialPostDto>.of(_posts),
          initialIndex: index,
          nextPage: _page,
          hasMore: _page <= _totalPages,
          loadPage: (page) => SocialPostsRepository.instance.fetchByAuthor(
            type: widget.author.type,
            id: widget.author.id,
            page: page,
          ),
        ),
      ),
    );
    if (mounted) {
      if (changed == true) {
        _loadPosts(reset: true);
      } else {
        setState(() {
          _totalLikes = _posts.fold<int>(0, (sum, p) => sum + p.likeCount);
          _totalViews = _posts.fold<int>(0, (sum, p) => sum + p.viewCount);
        });
      }
    }
  }

  void _goToRestaurant() {
    AppHaptics.buttonTap();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailPage(
          id: widget.author.id.toString(),
          name: widget.author.displayName,
        ),
      ),
    );
  }

  String _formatCount(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141416),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141416),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: Text(
          widget.author.handle,
          style: AppFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: const Color(0xFF222228),
        onRefresh: () => _loadPosts(reset: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildProfileHeader()),
            if (_isShop)
              SliverToBoxAdapter(child: _buildGoToRestaurantButton()),
            if (_loading && _posts.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null && _posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: AppFonts.poppins(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _loadPosts(reset: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text(context.tr('social.retry')),
                      ),
                    ],
                  ),
                ),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: const Icon(
                            PhosphorIcons.videoCameraSlash,
                            color: Colors.white54,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('social.no_posts_creator'),
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No videos or photos shared yet.',
                          style: AppFonts.poppins(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              _buildGridView(),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          // Avatar
          _buildAvatar(),
          const SizedBox(height: 12),
          // Creator Name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.author.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_isAdmin || _isShop) ...[
                const SizedBox(width: 6),
                Icon(
                  PhosphorIconsFill.checkCircle,
                  color: _isAdmin ? const Color(0xFF00D1FF) : AppColors.primary,
                  size: 18,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Handle
          Text(
            widget.author.handle,
            style: AppFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
          if (_isShop) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Shop Partner',
                style: AppFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          if (!_isAdmin && widget.author.id > 0) ...[
            const SizedBox(height: 14),
            Text(
              '$_followerCount ${context.tr('social.followers')}',
              style: AppFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_canFollow) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 180,
                height: 44,
                child: FilledButton(
                  onPressed: _followBusy ? null : _toggleFollow,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _followed ? Colors.white12 : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    context.tr(
                      _followed ? 'social.following' : 'social.follow',
                    ),
                    style: AppFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          // Stats Row (real posts count, real likes, and real viewers)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(
                count: _formatCount(_totalElements),
                label: context.tr('social.posts_count'),
              ),
              Container(
                height: 24,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white12,
              ),
              _buildStatItem(
                count: _formatCount(_totalLikes),
                label: context.tr('social.likes_count'),
              ),
              Container(
                height: 24,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white12,
              ),
              _buildStatItem(
                count: _formatCount(_totalViews),
                label: context.tr('social.viewers_count'),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _buildAvatar() {
    final avatarUrl = widget.author.avatarUrl;
    final isSuperAdmin = widget.author.displayName
        .toLowerCase()
        .contains('super admin');
    final isUser = widget.author.type == SocialAuthorType.user;

    Widget avatarContent;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarContent = CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => _buildFallbackAvatar(isSuperAdmin),
      );
    } else {
      avatarContent = _buildFallbackAvatar(isSuperAdmin);
    }

    final gradient = isUser
        ? _getGradientForName(widget.author.displayName)
        : AppColors.primaryGradient;

    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: isUser
                ? gradient.colors.first.withValues(alpha: 0.35)
                : AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF141416),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(child: avatarContent),
      ),
    );
  }

  Widget _buildFallbackAvatar(bool isSuperAdmin) {
    if (isSuperAdmin) {
      return Image.asset(
        'assets/images/super_admin.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/logo_3d.png',
          fit: BoxFit.cover,
        ),
      );
    }
    if (widget.author.type == SocialAuthorType.shop) {
      return Image.asset(
        'assets/images/logo_3d.png',
        fit: BoxFit.cover,
      );
    }

    final initials = _extractInitials(widget.author.displayName);
    final gradient = _getGradientForName(widget.author.displayName);
    final isTwoLetters = initials.length > 1;

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
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
          Center(
            child: Text(
              initials,
              style: AppFonts.poppins(
                color: Colors.white,
                fontSize: isTwoLetters ? 28 : 36,
                fontWeight: FontWeight.w700,
                letterSpacing: isTwoLetters ? -1 : 0,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required String count, required String label}) {
    return Column(
      children: [
        Text(
          count,
          style: AppFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // "Go to Restaurant" Action Button (Primary Gradient, Shop account only)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGoToRestaurantButton() {
    return Container(
      width: double.infinity,
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _goToRestaurant,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                PhosphorIcons.storefront,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('social.go_to_restaurant'),
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Grid Style View (3-column thumbnails with video icon & like count)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGridView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 3 / 4,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = _posts[index];
            final media = post.primaryMedia;
            final isVideo = media?.isVideo ?? false;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openPreview(index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (media == null)
                      ColoredBox(
                        color: const Color(0xFF25252A),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Center(
                            child: Text(
                              post.caption,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppFonts.poppins(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: isVideo ? media.previewUrl : media.url,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const ColoredBox(
                          color: Color(0xFF25252A),
                          child: Icon(
                            PhosphorIconsFill.play,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    // Video indicator
                    if (isVideo)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          PhosphorIconsFill.playCircle,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                    else if (post.media.length > 1)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          PhosphorIconsFill.copy,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    // Stats overlay at bottom (Viewer count & Like count)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Viewer count
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  PhosphorIconsFill.eye,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatCount(post.viewCount),
                                  style: AppFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            // Like count
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  PhosphorIconsFill.heart,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatCount(post.likeCount),
                                  style: AppFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
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
          },
          childCount: _posts.length,
        ),
      ),
    );
  }
}
