import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/news_image_viewer.dart';
import '../../data/models/news_item.dart';

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
  final PageController _pageController = PageController(viewportFraction: 0.80);
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isGifPickerVisible = false;
  
  // These were causing errors after being deleted
  final List<String> _trendingGifs = [];
  final bool _isLoadingGifs = false;

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
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {}
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
      _comments.insert(0, NewsComment(
        authorName: 'You',
        authorAvatar: 'https://i.pravatar.cc/150?u=you',
        content: text,
        timeAgo: 'Just now',
        gifUrl: gifUrl,
      ));
    });
  }

  void _toggleGifPicker() {
    setState(() {
      _isGifPickerVisible = !_isGifPickerVisible;
      if (_isGifPickerVisible) {
        _commentFocusNode.unfocus();
      }
    });
  }

  final List<String> _fallbackGifs = [
    'https://i.giphy.com/media/3o7TKMGpxVf7C1pG0M/200.gif',
    'https://i.giphy.com/media/l0HlHFRbmaZtBRhXG/200.gif',
    'https://i.giphy.com/media/3o7TKVUn7iM8FMEU24/200.gif',
    'https://i.giphy.com/media/26AHONQ79FdWzhAI0/200.gif',
    'https://i.giphy.com/media/3o7TKV4YyM7BMrANMc/200.gif',
    'https://i.giphy.com/media/3o7TKvaO83GZAnRE0o/200.gif',
    'https://i.giphy.com/media/l41lTfVp2m9PZ9m1O/200.gif',
    'https://i.giphy.com/media/3o84sq21z7SBiqpCxy/200.gif',
    'https://i.giphy.com/media/26n6R4xg77ekzchRS/200.gif',
    'https://i.giphy.com/media/l0MYvV3LXpxS8G3ug/200.gif',
    'https://i.giphy.com/media/3o7TKDkRoU6AN0p1u0/200.gif',
    'https://i.giphy.com/media/26AHvXn1pWvS/200.gif',
    'https://i.giphy.com/media/3o84sq2Y10kK1G9mS0/200.gif',
    'https://i.giphy.com/media/l0HlUvH6yA6H3ug/200.gif',
    'https://i.giphy.com/media/l41lS9B5kQpWpH1m0/200.gif',
  ];

  // Modified to return only fallbacks as all external APIs are disabled
  Future<List<String>> _fetchGifs() async {
    return _fallbackGifs;
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
                      ? Icon(PhosphorIcons.user(), size: 14, color: Colors.grey[400])
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFED3973), Color(0xFFFBA15C)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.phoneCall(PhosphorIconsStyle.fill), 
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
            centerTitle: false,
            titleSpacing: 0,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: outerPadding, right: outerPadding, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), 
                          color: const Color(0xFFED3973), size: 18),
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
                        Icon(PhosphorIcons.moneyWavy(PhosphorIconsStyle.fill), 
                          color: const Color(0xFF48BB78), size: 18),
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

          if (widget.item.imageUrls.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: widget.item.imageUrls.length == 1
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: outerPadding),
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
                            );
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
                                placeholder: (context, url) => Container(color: Colors.grey[100]),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[100],
                                  child: Icon(PhosphorIcons.image(), color: Colors.grey[400]),
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
                          padding: const EdgeInsets.symmetric(horizontal: outerPadding),
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
                                );
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
                                      placeholder: (context, url) => Container(color: Colors.grey[100]),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[100],
                                        child: Icon(PhosphorIcons.image(), color: Colors.grey[400]),
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
                            _isLiked ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                            color: _isLiked ? const Color(0xFFED3973) : Colors.black87,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCount(_likesCount),
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () => _commentFocusNode.requestFocus(),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.chatCircle(), color: Colors.black87, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                _formatCount(widget.item.commentsCount),
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 20),
                  Text(
                    'Comments',
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

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final comment = _comments[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: outerPadding, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: CachedNetworkImageProvider(comment.authorAvatar),
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
              },
              childCount: _comments.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
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
              color: Colors.black.withOpacity(0.05),
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
                        hintText: 'Add a comment...',
                        hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        suffixIcon: GestureDetector(
                          onTap: _toggleGifPicker,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              PhosphorIcons.gif(PhosphorIconsStyle.bold),
                              color: _isGifPickerVisible ? const Color(0xFFED3973) : Colors.grey[600],
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
                      color: Color(0xFFED3973),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
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
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFED3973)))
                  : _fallbackGifs.isEmpty
                      ? const SizedBox.shrink()
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _fallbackGifs.length,
                          itemBuilder: (context, index) {
                            final url = _fallbackGifs[index];
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
                                  placeholder: (context, url) => Container(color: Colors.grey[100]),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[100],
                                    child: const Icon(Icons.error_outline, size: 16),
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
