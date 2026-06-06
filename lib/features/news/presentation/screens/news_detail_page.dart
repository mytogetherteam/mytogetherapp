import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/news_image_viewer.dart';
import '../../data/models/news_item.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

class NewsComment {
  final String authorName;
  final String authorAvatar;
  final String content;
  final String timeAgo;
  final String? gifUrl;

  NewsComment({
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timeAgo,
    this.gifUrl,
  });
}

class NewsDetailPage extends StatefulWidget {
  final NewsItem item;
  final bool autoFocusComment;

  const NewsDetailPage({
    super.key,
    required this.item,
    this.autoFocusComment = false,
  });

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  late bool _isLiked;
  late int _likesCount;
  // Use viewportFraction 0.80 for the "peek" effect, matching the feed
  final PageController _pageController = PageController(viewportFraction: 0.80);
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isGifPickerVisible = false;
  List<String> _trendingGifs = [];
  bool _isLoadingGifs = false;

  late List<NewsComment> _comments;

  final List<NewsComment> _initialMocks = [
    NewsComment(
      authorName: 'Alex Rivers',
      authorAvatar: 'https://i.pravatar.cc/150?u=alex',
      content: 'This is such an insightful update! Thanks for sharing.',
      timeAgo: '2h ago',
    ),
    NewsComment(
      authorName: 'Sarah Jenkins',
      authorAvatar: 'https://i.pravatar.cc/150?u=sarah',
      content: 'I completely agree. The attention to detail is amazing.',
      timeAgo: '1h ago',
    ),
    NewsComment(
      authorName: 'Michael Chen',
      authorAvatar: 'https://i.pravatar.cc/150?u=mike',
      content: 'Can\'t wait to see what\'s next!',
      timeAgo: '45m ago',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likesCount = widget.item.likesCount;
    _comments = List.from(_initialMocks);

    // Handle auto-focus for comments if triggered from feed
    if (widget.autoFocusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
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
    debugPrint('Attempting to call from detail: $phoneNumber');
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        debugPrint('Could not launch from detail $launchUri');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('news.dialer_failed'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching call from detail: $e');
    }
  }

  void _postComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      _addComment(text: text);
      _commentController.clear();
      _commentFocusNode.unfocus();
      if (_isGifPickerVisible) {
        setState(() => _isGifPickerVisible = false);
      }
    }
  }

  void _addComment({String text = '', String? gifUrl}) {
    setState(() {
      _comments.insert(
        0,
        NewsComment(
          authorName: 'You',
          authorAvatar: 'https://i.pravatar.cc/150?u=you',
          content: text,
          timeAgo: 'Just now',
          gifUrl: gifUrl,
        ),
      );
    });
  }

  void _toggleGifPicker() {
    setState(() {
      _isGifPickerVisible = !_isGifPickerVisible;
      if (_isGifPickerVisible) {
        _commentFocusNode.unfocus();
        if (_trendingGifs.isEmpty) {
          _fetchGifsToCache();
        }
      }
    });
  }

  Future<void> _fetchGifsToCache() async {
    setState(() {
      _isLoadingGifs = true;
      _trendingGifs = []; // Clear previous errors
    });
    final gifs = await _fetchGifs();
    if (mounted) {
      setState(() {
        _trendingGifs = gifs;
        _isLoadingGifs = false;
      });
    }
  }

  final List<String> _fallbackGifs = [
    'https://i.giphy.com/media/3o7TKMGpxVf7C1pG0M/200.gif', // Happy
    'https://i.giphy.com/media/l0HlHFRbmaZtBRhXG/200.gif', // Confused
    'https://i.giphy.com/media/3o7TKVUn7iM8FMEU24/200.gif', // Love
    'https://i.giphy.com/media/26AHONQ79FdWzhAI0/200.gif', // Cool
    'https://i.giphy.com/media/3o7TKV4YyM7BMrANMc/200.gif', // Excited
    'https://i.giphy.com/media/3o7TKvaO83GZAnRE0o/200.gif', // Smile
    'https://i.giphy.com/media/l41lTfVp2m9PZ9m1O/200.gif', // Wow
    'https://i.giphy.com/media/3o84sq21z7SBiqpCxy/200.gif', // Celebrate
    'https://i.giphy.com/media/26n6R4xg77ekzchRS/200.gif', // Clap
    'https://i.giphy.com/media/l0MYvV3LXpxS8G3ug/200.gif', // Dancing
    'https://i.giphy.com/media/3o7TKDkRoU6AN0p1u0/200.gif', // Thumbs up
    'https://i.giphy.com/media/26AHvXn1pWvS/200.gif', // Shock
    'https://i.giphy.com/media/3o84sq2Y10kK1G9mS0/200.gif', // Laugh
    'https://i.giphy.com/media/l0HlUvH6yA6H3ug/200.gif', // Party
    'https://i.giphy.com/media/l41lS9B5kQpWpH1m0/200.gif', // Cry
  ];

  Future<List<String>> _fetchGifs() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final response = await dio.get(
        'https://tenor.googleapis.com/v2/featured',
        queryParameters: {
          'key': 'LIVDSRZULELA', // Public demo key
          'limit': 15,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final List results = response.data['results'] ?? [];
        final List<String> gifs = results.map((e) {
          final formats = e['media_formats'] as Map<String, dynamic>;
          final gifData =
              formats['tinygif'] ?? formats['gif'] ?? formats['mediumgif'];
          return (gifData['url'] as String).replaceFirst('http:', 'https:');
        }).toList();
        if (gifs.isNotEmpty) return gifs;
      }
      return _fallbackGifs;
    } catch (e) {
      debugPrint('Tenor Exception: $e');
      return _fallbackGifs;
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
    const double outerPadding = 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Header: Consistent minimalist App Bar with Author Info
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: widget.item.authorAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(widget.item.authorAvatar)
                      : null,
                  backgroundColor: Colors.grey[100],
                  child: widget.item.authorAvatar.isEmpty
                      ? Icon(
                          PhosphorIcons.user,
                          size: 14,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.item.authorName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.item.timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black45,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.item.phoneNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: () => _makeCall(widget.item.phoneNumber!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
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
            centerTitle: false,
            titleSpacing: 0, // Reduces gap between back button and profile
          ),

          // Main Post Content (Restructured to respect new Author location)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: outerPadding,
                right: outerPadding,
                top: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description text (Aligned to full width)
                  // Description text
                  Text(
                    widget.item.content,
                    style: GoogleFonts.notoSansMyanmar(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (widget.item.location != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.mapPinFill,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.item.location!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF7B8794),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.item.rewardAmount != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.moneyWavyFill,
                          color: const Color(0xFF48BB78),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.item.rewardAmount!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF768CA2),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Image Gallery (Edge-to-edge swiping section)
          if (widget.item.imageUrls.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: widget.item.imageUrls.length == 1
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: outerPadding,
                        ),
                        child: GestureDetector(
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: widget.item.imageUrls[0],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 180,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey[100]),
                                errorWidget: (context, url, error) => Container(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: outerPadding,
                          ), // Keeps initial alignment but allows swiping into "edges"
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
                                width: MediaQuery.of(context).size.width * 0.75,
                                margin: const EdgeInsets.only(right: 12),
                                child: Hero(
                                  tag: imageUrl,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(
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
            ),

          // Interaction Row & Comments
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: outerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Icon(
                            _isLiked
                                ? PhosphorIcons.heartFill
                                : PhosphorIcons.heart,
                            color: _isLiked
                                ? AppColors.primary
                                : Colors.black87,
                            size: 22,
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
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () => _commentFocusNode.requestFocus(),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.chatCircle,
                                color: Colors.black87,
                                size: 22,
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
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFEEEEEE),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('news.comments'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Comments List
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final comment = _comments[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: outerPadding,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: CachedNetworkImageProvider(
                        comment.authorAvatar,
                      ),
                      backgroundColor: Colors.grey[100],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                comment.authorName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                comment.timeAgo,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (comment.content.isNotEmpty)
                            Text(
                              comment.content,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          if (comment.gifUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: comment.gifUrl!,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 150,
                                    width: 200,
                                    color: Colors.grey[100],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }, childCount: _comments.length),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      // Sticky Comment Input
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      onTap: () {
                        if (_isGifPickerVisible) {
                          setState(() => _isGifPickerVisible = false);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: context.tr('news.add_comment'),
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: _toggleGifPicker,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              PhosphorIcons.gifBold,
                              color: _isGifPickerVisible
                                  ? AppColors.primary
                                  : Colors.grey[600],
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.paperPlaneRightFill,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              height: _isGifPickerVisible ? 200 : 0,
              padding: const EdgeInsets.only(top: 12),
              child: _isLoadingGifs
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _trendingGifs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.warningCircle,
                            color: Colors.grey[400],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('news.failed_gifs'),
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: _fetchGifsToCache,
                            child: GradientText(
                              context.tr('common.retry'),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: _trendingGifs.length,
                      itemBuilder: (context, index) {
                        final url = _trendingGifs[index];
                        return GestureDetector(
                          onTap: () {
                            _addComment(gifUrl: url);
                            setState(() => _isGifPickerVisible = false);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[100]),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[100],
                                child: const Icon(
                                  Icons.error_outline,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
