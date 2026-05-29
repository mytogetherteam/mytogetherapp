import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'news_image_viewer.dart'; // Added import
import '../../data/models/news_item.dart';
import '../screens/news_detail_page.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';

class NewsFeedItem extends StatefulWidget {
  final NewsItem item;

  const NewsFeedItem({
    super.key,
    required this.item,
  });

  @override
  State<NewsFeedItem> createState() => _NewsFeedItemState();
}

class _NewsFeedItemState extends State<NewsFeedItem> {
  late bool _isLiked;
  late int _likesCount;
  // _pageController is no longer needed for ListView.builder
  // late PageController _pageController;
  final int _currentImageIndex = 0;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likesCount = widget.item.likesCount;
    // viewportFraction only relevant for multiple images to show "peek"
    // _pageController = PageController(viewportFraction: 0.80, initialPage: 0);
  }

  @override
  void dispose() {
    // _pageController.dispose(); // No longer needed
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likesCount++;
      } else {
        _likesCount--;
      }
    });
  }

  Future<void> _makeCall(String phoneNumber) async {
    debugPrint('Attempting to call: $phoneNumber');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        debugPrint('Could not launch $launchUri');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching call: $e');
    }
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    const double avatarRadius = 20.0;
    const double avatarGap = 14.0;
    const double outerPadding = 16.0;
    const double leftContentOffset = outerPadding + (avatarRadius * 2) + avatarGap; // 16 + 40 + 14 = 70

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Main Tappable Area for Detail Page
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NewsDetailPage(item: widget.item)),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Section: Avatar and Content
                  Padding(
                    padding: const EdgeInsets.only(left: outerPadding, top: 20.0, right: outerPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Avatar
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
                        // Right Column: Content text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.item.authorName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Placeholder for Connect button to maintain layout height
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
                              // (Rest of the content remains inside this GestureDetector)
                          if (widget.item.location != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(PhosphorIconsFill.mapPin, 
                                  color: AppColors.primary, size: 18),
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
                          if (widget.item.rewardAmount != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(PhosphorIconsFill.moneyWavy, 
                                  color: const Color(0xFF48BB78), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  widget.item.rewardAmount!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF768CA2),
                                    fontWeight: FontWeight.w500,
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

                              if (_isExpanded || !isLong) {
                                return Text(
                                  content,
                                  style: GoogleFonts.notoSansMyanmar(
                                    fontSize: 13,
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
                                        fontSize: 13,
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
                                          'See more',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
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
                              MaterialPageRoute(
                                builder: (context) => NewsImageViewer(
                                  imageUrls: widget.item.imageUrls,
                                  initialIndex: 0,
                                  item: widget.item,
                                ),
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
                              // Single image: Reduced width (with extra right padding) for better proportion
                              padding: const EdgeInsets.only(left: leftContentOffset, right: 40.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: widget.item.imageUrls[0],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 180, // Slightly reduced height to match the narrower width
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[100],
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[100],
                                    child: Icon(PhosphorIcons.image, color: Colors.grey[400]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 190,
                          child: ListView.builder( // Changed from PageView.builder to ListView.builder
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: widget.item.imageUrls.length,
                            padding: EdgeInsets.zero, // Removed padding from here, added to individual items
                            itemBuilder: (context, index) {
                              final imageUrl = widget.item.imageUrls[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                    builder: (context) => NewsImageViewer(
                                      imageUrls: widget.item.imageUrls,
                                      initialIndex: index,
                                      item: widget.item,
                                    ),
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
                                  width: MediaQuery.of(context).size.width * 0.75, // Adjusted width
                                  margin: EdgeInsets.only(
                                    left: index == 0 ? leftContentOffset : 0,
                                    right: 12.0,
                                  ),
                                  child: Hero(
                                    tag: imageUrl,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[100],
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[100],
                                          child: Icon(PhosphorIcons.image, color: Colors.grey[400]),
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

            // Actual Connect Button (Placed on top of the Stack)
            if (widget.item.phoneNumber != null)
              Positioned(
                top: 25, // Aligned with the author row
                right: outerPadding,
                child: GestureDetector(
                  onTap: () => _makeCall(widget.item.phoneNumber!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.primaryGradient.colors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsFill.phoneCall, 
                          color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Connect',
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
          padding: const EdgeInsets.only(left: leftContentOffset, top: 12.0, right: outerPadding, bottom: 20.0),
          child: Row(
            children: [
              // Like
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _isLiked ? PhosphorIconsFill.heart : PhosphorIcons.heart,
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsDetailPage(item: widget.item, autoFocusComment: true),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(PhosphorIcons.chatCircle, color: Colors.black87, size: 24),
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
