import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'news_image_viewer.dart'; // Added import
import '../../data/models/news_item.dart';
import '../../data/repositories/news_repository.dart';
import '../../../lost_and_found/data/repositories/item_post_repository.dart';
import '../screens/news_detail_page.dart';
import '../../../auth/presentation/screens/auth_entry_page.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/auth/guest_auth_guard.dart';

class NewsFeedItem extends StatefulWidget {
  final NewsItem item;
  final bool showProfile;
  final bool showBlockOption;

  const NewsFeedItem({
    super.key,
    required this.item,
    this.showProfile = true,
    this.showBlockOption = false,
  });

  @override
  State<NewsFeedItem> createState() => _NewsFeedItemState();
}

class _NewsFeedItemState extends State<NewsFeedItem> {
  late bool _isLiked;
  late int _likesCount;
  bool _isExpanded = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likesCount = widget.item.likesCount;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;

    final previousLiked = _isLiked;
    final previousCount = _likesCount;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    if (!widget.item.isApiBacked) return;

    try {
      final id = widget.item.entityId!;
      final result = widget.item.source == FeedSource.news
          ? await NewsRepository.instance.toggleLike(id)
          : await ItemPostRepository.instance.toggleLike(id);
      if (!mounted) return;
      setState(() {
        _isLiked = result.liked;
        _likesCount = result.likeCount;
        widget.item.isLiked = result.liked;
        widget.item.likesCount = result.likeCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = previousLiked;
        _likesCount = previousCount;
      });
    }
  }

  void _openDetail({bool autoFocusComment = false}) {
    if (widget.item.source == FeedSource.itemPost && GuestAuthGuard.isGuest) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthEntryPage()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailPage(
          item: widget.item,
          autoFocusComment: autoFocusComment,
        ),
      ),
    ).then((_) {
      // Refresh likes/comment counts that may have changed in the detail page
      // (e.g. the user deleted their comment), so the feed icons stay accurate.
      if (mounted) {
        setState(() {
          _isLiked = widget.item.isLiked;
          _likesCount = widget.item.likesCount;
        });
      }
    });
  }

  Future<void> _openComments() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    _openDetail(autoFocusComment: true);
  }

  Future<void> _makeCall(String phoneNumber) async {
    debugPrint('Attempting to call: $phoneNumber');
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        debugPrint('Could not launch $launchUri');
        if (mounted) {
          AppDialog.showToast(context, context.tr('news.dialer_failed'), isError: true);
        }
      }
    } catch (e) {
      debugPrint('Error launching call: $e');
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(PhosphorIcons.warningCircle, color: Colors.orange),
                title: Text(
                  context.tr('news.report_post'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleReport();
                },
              ),
              if (widget.showBlockOption)
                ListTile(
                  leading: const Icon(PhosphorIcons.userMinus, color: Colors.red),
                  title: Text(
                    context.tr('news.block_user'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleBlock();
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _handleReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset('assets/images/app_icon_small.png', width: 28, height: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('news.report_post'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17))),
          ],
        ),
        content: Text(context.tr('news.report_confirm'), style: GoogleFonts.poppins(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel'), style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AppDialog.showToast(context, context.tr('news.reported_success'));
            },
            child: Text(context.tr('news.report_action'), style: GoogleFonts.poppins(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleBlock() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset('assets/images/app_icon_small.png', width: 28, height: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('news.block_user'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.red))),
          ],
        ),
        content: Text(context.tr('news.block_confirm'), style: GoogleFonts.poppins(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel'), style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isBlocked = true;
              });
              AppDialog.showToast(context, context.tr('news.blocked_success'));
            },
            child: Text(context.tr('news.block_action'), style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBlocked) {
      return const SizedBox.shrink();
    }
    const double outerPadding = 16.0;
    const double avatarRadius = 24.0;
    const double avatarGap = 14.0;
    final double leftContentOffset = widget.showProfile
        ? outerPadding + (avatarRadius * 2) + avatarGap
        : outerPadding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Main Tappable Area for Detail Page
            GestureDetector(
              onTap: () => _openDetail(),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Section: Content
                  Padding(
                    padding: const EdgeInsets.only(
                      left: outerPadding,
                      top: 20.0,
                      right: outerPadding,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showProfile) ...[
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundImage: widget.item.authorAvatar.isNotEmpty
                                ? CachedNetworkImageProvider(widget.item.authorAvatar)
                                : null,
                            backgroundColor: Colors.grey[100],
                            child: widget.item.authorAvatar.isEmpty
                                ? Icon(PhosphorIcons.user, size: 22, color: Colors.grey[400])
                                : null,
                          ),
                          const SizedBox(width: avatarGap),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.item.authorName,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            if (widget.item.itemPostType != null) ...[
                              const SizedBox(width: 8),
                              _ItemPostTypeBadge(
                                type: widget.item.itemPostType!,
                              ),
                            ],
                            const Spacer(),
                            if (widget.item.phoneNumber != null)
                              const SizedBox(width: 80, height: 30),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              widget.item.timeAgo,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        if (widget.item.location != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                PhosphorIcons.mapPinFill,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.item.location!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF7B8794),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final content = widget.item.content;
                            const int charLimit = 120;
                            final bool isLong = content.length > charLimit;

                            if (_isExpanded && isLong) {
                              return Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$content ',
                                      style: GoogleFonts.notoSansMyanmar(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isExpanded = false;
                                          });
                                        },
                                        child: GradientText(
                                          context.tr('news.see_less') == 'news.see_less' ? 'See less' : context.tr('news.see_less'),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (!isLong) {
                              return Text(
                                content,
                                style: GoogleFonts.notoSansMyanmar(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              );
                            }

                            return Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${content.substring(0, charLimit)}... ',
                                    style: GoogleFonts.notoSansMyanmar(
                                      fontSize: 14,
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isExpanded = true;
                                        });
                                      },
                                      child: GradientText(
                                        context.tr('news.see_more'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

            // Middle Section: Single or Multiple Images
                  if (widget.item.imageUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: widget.item.imageUrls.length == 1
                          ? GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    opaque: false,
                                    transitionDuration: const Duration(milliseconds: 300),
                                    pageBuilder: (context, _, _) => NewsImageViewer(
                                      imageUrls: widget.item.imageUrls,
                                      initialIndex: 0,
                                      item: widget.item,
                                    ),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                ).then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _isLiked = widget.item.isLiked;
                                      _likesCount = widget.item.likesCount;
                                    });
                                  }
                                });
                              },
                              child: Hero(
                                tag: widget.item.imageUrls[0],
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: leftContentOffset,
                                    right: 40.0,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                      imageUrl: widget.item.imageUrls[0],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 180,
                                      placeholder: (context, url) =>
                                          Container(color: Colors.grey[100]),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: Colors.grey[100],
                                            child: Icon(
                                              PhosphorIcons.image,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 190,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: widget.item.imageUrls.length,
                                padding: EdgeInsets.zero,
                                itemBuilder: (context, index) {
                                  final imageUrl = widget.item.imageUrls[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          opaque: false,
                                          transitionDuration: const Duration(milliseconds: 300),
                                          pageBuilder: (context, _, _) => NewsImageViewer(
                                            imageUrls: widget.item.imageUrls,
                                            initialIndex: index,
                                            item: widget.item,
                                          ),
                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                            return FadeTransition(opacity: animation, child: child);
                                          },
                                        ),
                                      ).then((_) {
                                        if (mounted) {
                                          setState(() {
                                            _isLiked = widget.item.isLiked;
                                            _likesCount = widget.item.likesCount;
                                          });
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: MediaQuery.of(context).size.width * 0.75,
                                      margin: EdgeInsets.only(
                                        left: index == 0 ? leftContentOffset : 0,
                                        right: 12.0,
                                      ),
                                      child: Hero(
                                        tag: imageUrl,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                            imageUrl: imageUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            placeholder: (context, url) =>
                                                Container(color: Colors.grey[100]),
                                            errorWidget: (context, url, error) =>
                                                Container(
                                                  color: Colors.grey[100],
                                                  child: Icon(
                                                    PhosphorIcons.image,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                ],
              ),
            ),

            // Ellipsis Menu
            Positioned(
              top: 20, // Aligned with the author row
              right: 0,
              child: IconButton(
                icon: const Icon(PhosphorIcons.dotsThreeVerticalBold, size: 20, color: Colors.grey),
                onPressed: _showMoreOptions,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),

            // Actual Connect Button (Placed on top of the Stack)
            if (widget.item.phoneNumber != null)
              Positioned(
                top: 25, // Aligned with the author row
                right: outerPadding + 28, // Moved left to make room for ellipsis menu
                child: GestureDetector(
                  onTap: () => _makeCall(widget.item.phoneNumber!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.primaryGradient.colors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.phoneCallFill,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('news.connect'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Bottom Section: Interaction Buttons
        Padding(
          padding: EdgeInsets.only(
            left: leftContentOffset,
            top: 12.0,
            right: outerPadding,
            bottom: 20.0,
          ),
          child: Row(
            children: [
              // Like
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _isLiked
                      ? PhosphorIcons.heartFill
                      : PhosphorIcons.heart,
                  color: _isLiked ? AppColors.primary : Colors.black87,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatCount(_likesCount),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 20),
              // Comment
              GestureDetector(
                onTap: _openComments,
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.chatCircle,
                      color: Colors.black87,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCount(widget.item.commentsCount),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}

/// Small pill that labels a Lost & Found post as LOST or FOUND.
class _ItemPostTypeBadge extends StatelessWidget {
  final String type;

  const _ItemPostTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isFound = type.toUpperCase() == 'FOUND';
    final Color color = isFound ? const Color(0xFF48BB78) : AppColors.primary;
    final String label = isFound
        ? context.tr('lost.badge_found')
        : context.tr('lost.badge_lost');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFound
                ? PhosphorIcons.checkCircleFill
                : PhosphorIcons.magnifyingGlassFill,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

