import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import 'package:mytogetherapp/core/utils/navigation_controller.dart';
import 'package:mytogetherapp/features/social/data/models/post_dto.dart';
import 'package:mytogetherapp/features/social/data/repositories/social_posts_repository.dart';
import 'view_all_icon_button.dart';

/// Home teaser for Social — first N posts from the For You feed.
class SocialForYouSection extends StatefulWidget {
  const SocialForYouSection({super.key});

  @override
  State<SocialForYouSection> createState() => _SocialForYouSectionState();
}

class _SocialForYouSectionState extends State<SocialForYouSection> {
  List<SocialPostDto> _posts = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page =
          await SocialPostsRepository.instance.fetchFeed(page: 1, size: 8);
      if (!mounted) return;
      setState(() {
        _posts = page.items;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _openSocial() {
    AppHaptics.buttonTap();
    NavigationController.instance.goToSocialTab();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _posts.isEmpty && !_failed) {
      // Hide section entirely when feed is empty (no placeholders).
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('social.home_teaser_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('social.home_teaser_subtitle'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ViewAllIconButton(onPressed: _openSocial),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: _loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 4,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
              : _failed
                  ? Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _failed = false;
                          });
                          _load();
                        },
                        child: Text(context.tr('social.retry')),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _posts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        return _SocialTeaserCard(
                          post: post,
                          onTap: _openSocial,
                        );
                      },
                    ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SocialTeaserCard extends StatelessWidget {
  final SocialPostDto post;
  final VoidCallback onTap;

  const _SocialTeaserCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preview = post.primaryMedia?.previewUrl ?? '';
    final isVideo = post.primaryMedia?.isVideo == true;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 120,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: preview,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey.shade200),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(
                      PhosphorIcons.playFill,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                Container(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(
                    PhosphorIcons.playFill,
                    color: AppColors.primary,
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              if (isVideo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIcons.playFill,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  post.author.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}
