import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';

import '../../data/models/post_dto.dart';
import '../../data/repositories/social_posts_repository.dart';
import 'create_social_post_page.dart';
import 'social_page.dart';

/// This user's own posts, newest first, including hidden ones.
class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  /// Returns true when a post was published or deleted, so the feed can refresh.
  static Future<bool> open(BuildContext context) async {
    if (!await GuestAuthGuard.requireAccount(context)) return false;
    if (!context.mounted) return false;
    AppHaptics.buttonTap();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MyPostsPage()),
    );
    return changed == true;
  }

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final _posts = <SocialPostDto>[];
  final _scroll = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  int _generation = 0;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _generation += 1;
      _page = 1;
      _totalPages = 1;
    } else if (_loading || _loadingMore || _page > _totalPages) {
      return;
    }
    final generation = _generation;
    final page = _page;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await SocialPostsRepository.instance.fetchMine(page: page);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(result.items);
        _totalPages = result.totalPages;
        _page = page + 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = context.tr('social.my_posts_load_failed');
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateSocialPostPage()),
    );
    if (created == true) {
      _changed = true;
      _load(reset: true);
    }
  }

  Future<void> _openPreview(int index) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OwnPostsPreviewPage(
          posts: List<SocialPostDto>.of(_posts),
          initialIndex: index,
          nextPage: _page,
          hasMore: _page <= _totalPages,
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_changed) SocialPostsRepository.markFeedChanged();
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          context.tr('social.my_posts'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _openCreate,
            child: Text(
              context.tr('social.new_post'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: GoogleFonts.poppins()),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _load(reset: true),
                        child: Text(context.tr('social.retry')),
                      ),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('social.my_posts_empty'),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr('social.my_posts_empty_sub'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _openCreate,
                              child: Text(context.tr('social.new_post')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: GridView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          return _postTile(context, _posts[index], index);
                        },
                      ),
                    ),
      ),
    );
  }

  Widget _postTile(BuildContext context, SocialPostDto post, int index) {
    final media = post.primaryMedia;
    return GestureDetector(
      onTap: () => _openPreview(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media == null)
              ColoredBox(
                color: AppColors.primary.withValues(alpha: 0.18),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, post.isActive ? 8 : 22, 8, 8),
                  child: Center(
                    child: post.caption.isEmpty
                        ? const Icon(
                            PhosphorIcons.textT,
                            color: AppColors.primary,
                            size: 22,
                          )
                        : Text(
                            post.caption,
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                  ),
                ),
              )
            else if (media.isVideo &&
                (media.thumbnailUrl == null || media.thumbnailUrl!.isEmpty))
              const ColoredBox(
                color: Colors.black87,
                child: Icon(PhosphorIconsFill.play, color: Colors.white),
              )
            else
              CachedNetworkImage(
                imageUrl: media.isVideo ? media.previewUrl : media.url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Colors.black87,
                  child: Icon(PhosphorIconsFill.play, color: Colors.white),
                ),
              ),
            if (post.media.any((item) => item.isVideo))
              const Positioned(
                left: 6,
                bottom: 6,
                child: Icon(
                  PhosphorIconsFill.playCircle,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            if (!post.isActive)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.tr('social.hidden'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
