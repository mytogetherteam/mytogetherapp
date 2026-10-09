import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/social/data/models/post_dto.dart';
import 'package:mytogetherapp/features/social/data/repositories/social_posts_repository.dart';
import 'package:mytogetherapp/features/social/presentation/screens/social_page.dart';

/// The shop's public posts, in the same grid as My posts.
class ShopPostsSection extends StatefulWidget {
  final int shopId;

  const ShopPostsSection({super.key, required this.shopId});

  @override
  State<ShopPostsSection> createState() => _ShopPostsSectionState();
}

class _ShopPostsSectionState extends State<ShopPostsSection> {
  final _posts = <SocialPostDto>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  int _generation = 0;
  String? _error;

  bool get _hasMore => _page <= _totalPages;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant ShopPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _load(reset: true);
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
      final result = await SocialPostsRepository.instance.fetchByShop(
        widget.shopId,
        page: page,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _posts.clear();
        final seen = _posts.map((post) => post.id).toSet();
        _posts.addAll(result.items.where((post) => seen.add(post.id)));
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
        if (reset || _posts.isEmpty) {
          _error = context.tr('social.shop_posts_load_failed');
        }
      });
    }
  }

  Future<void> _open(int index) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OwnPostsPreviewPage(
          posts: List<SocialPostDto>.of(_posts),
          initialIndex: index,
          nextPage: _page,
          hasMore: _page <= _totalPages,
          loadPage: (page) => SocialPostsRepository.instance.fetchByShop(
            widget.shopId,
            page: page,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Icon(
                    PhosphorIcons.squaresFour,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.tr('social.shop_posts'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(_error!, style: GoogleFonts.poppins(fontSize: 14)),
                  TextButton(
                    onPressed: () => _load(reset: true),
                    child: Text(context.tr('social.retry')),
                  ),
                ],
              ),
            )
          else if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.tr('social.shop_posts_empty'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                return _ShopPostTile(
                  post: _posts[index],
                  onTap: () => _open(index),
                );
              },
            ),
          if (!_loading && _posts.isNotEmpty && _hasMore)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _loadingMore ? null : () => _load(),
                child: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('social.see_more')),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopPostTile extends StatelessWidget {
  final SocialPostDto post;
  final VoidCallback onTap;

  const _ShopPostTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final media = post.primaryMedia;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media == null)
              ColoredBox(
                color: AppColors.primary.withValues(alpha: 0.18),
                child: Padding(
                  padding: const EdgeInsets.all(8),
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
          ],
        ),
      ),
    );
  }
}
