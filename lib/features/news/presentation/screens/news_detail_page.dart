import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/news_image_viewer.dart';
import '../../data/models/news_item.dart';
import '../../data/repositories/news_repository.dart';
import '../../../lost_and_found/data/repositories/item_post_repository.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

class NewsComment {
  final int? id;
  final String authorName;
  final String authorAvatar;
  final String content;
  final String timeAgo;
  final bool isMine;

  NewsComment({
    this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timeAgo,
    this.isMine = false,
  });

  NewsComment copyWith({String? content}) {
    return NewsComment(
      id: id,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content ?? this.content,
      timeAgo: timeAgo,
      isMine: isMine,
    );
  }
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

  List<NewsComment> _comments = [];

  /// True once the comment list has been fetched at least once. After that the
  /// counter is driven by the comments actually loaded (the source of truth for
  /// the rendered list) rather than the feed payload's `commentsCount`, which
  /// can be stale/0 and is what caused the icon to show 0 next to a visible
  /// comment.
  bool _commentsLoaded = false;

  /// Count shown next to the comment icon. Falls back to the feed value until
  /// the real comments arrive, then mirrors the loaded list exactly.
  int get _displayCommentCount =>
      _commentsLoaded ? _comments.length : widget.item.commentsCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likesCount = widget.item.likesCount;
    if (widget.item.isApiBacked) {
      _loadComments();
    }

    if (widget.autoFocusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusCommentIfSignedIn());
    }
  }

  Future<void> _focusCommentIfSignedIn() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    _commentFocusNode.requestFocus();
  }

  Future<void> _loadComments() async {
    final id = widget.item.entityId;
    if (id == null) return;
    final myId = AuthService().currentUser?.id;
    try {
      if (widget.item.source == FeedSource.news) {
        final rows = await NewsRepository.instance.fetchComments(id);
        if (!mounted) return;
        setState(() {
          _comments = rows
              .map(
                (c) => NewsComment(
                  id: c.id,
                  authorName: c.authorName,
                  authorAvatar: c.authorAvatar,
                  content: c.content,
                  timeAgo: c.timeAgo,
                  isMine: myId != null &&
                      (c.userId == myId || c.user?.id == myId),
                ),
              )
              .toList();
          _commentsLoaded = true;
          _syncCommentCount();
        });
      } else if (widget.item.source == FeedSource.itemPost) {
        final rows = await ItemPostRepository.instance.fetchComments(id);
        if (!mounted) return;
        setState(() {
          _comments = rows
              .map(
                (c) => NewsComment(
                  id: c.id,
                  authorName: c.authorName,
                  authorAvatar: c.authorAvatar,
                  content: c.content,
                  timeAgo: c.timeAgo,
                  isMine: myId != null && c.user?.id == myId,
                ),
              )
              .toList();
          _commentsLoaded = true;
          _syncCommentCount();
        });
      }
    } catch (_) {}
  }

  /// Keeps the feed item's comment counter in sync with the comments actually
  /// loaded/added/deleted here, so the count shown on the feed is correct when
  /// the user navigates back (e.g. after deleting their only comment).
  void _syncCommentCount() {
    if (widget.item.isApiBacked) {
      widget.item.commentsCount = _comments.length;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = previousLiked;
        _likesCount = previousCount;
      });
    }
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

  Future<void> _postComment() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    _commentFocusNode.unfocus();

    if (widget.item.isApiBacked && widget.item.entityId != null) {
      try {
        if (widget.item.source == FeedSource.news) {
          final created = await NewsRepository.instance.addComment(
            widget.item.entityId!,
            text,
          );
          if (created != null && mounted) {
            setState(() {
              _comments.insert(
                0,
                NewsComment(
                  id: created.id,
                  authorName: created.authorName,
                  authorAvatar: created.authorAvatar,
                  content: created.content,
                  timeAgo: created.timeAgo,
                  isMine: true,
                ),
              );
              _commentsLoaded = true;
              _syncCommentCount();
            });
          }
        } else if (widget.item.source == FeedSource.itemPost) {
          final created = await ItemPostRepository.instance.addComment(
            widget.item.entityId!,
            text,
          );
          if (created != null && mounted) {
            setState(() {
              _comments.insert(
                0,
                NewsComment(
                  id: created.id,
                  authorName: created.authorName,
                  authorAvatar: created.authorAvatar,
                  content: created.content,
                  timeAgo: created.timeAgo,
                  isMine: true,
                ),
              );
              _commentsLoaded = true;
              _syncCommentCount();
            });
          }
        }
      } catch (_) {
        _addComment(text: text);
      }
      return;
    }

    _addComment(text: text);
  }

  void _addComment({String text = ''}) {
    setState(() {
      _comments.insert(
        0,
        NewsComment(
          authorName: context.tr('news.you'),
          authorAvatar: 'https://i.pravatar.cc/150?u=you',
          content: text,
          timeAgo: context.tr('common.just_now'),
        ),
      );
      _commentsLoaded = true;
      _syncCommentCount();
    });
  }

  Future<void> _editComment(int index) async {
    final comment = _comments[index];
    final commentId = comment.id;
    final entityId = widget.item.entityId;
    if (commentId == null || entityId == null) return;

    final controller = TextEditingController(text: comment.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          context.tr('comment.edit'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 1,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );

    if (newText == null || newText.isEmpty || newText == comment.content) {
      return;
    }

    // Optimistic update with rollback on failure.
    setState(() => _comments[index] = comment.copyWith(content: newText));
    try {
      if (widget.item.source == FeedSource.news) {
        await NewsRepository.instance
            .updateComment(entityId, commentId, newText);
      } else {
        await ItemPostRepository.instance
            .updateComment(entityId, commentId, newText);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _comments[index] = comment);
      AppDialog.showToast(
        context,
        context.tr('comment.update_failed'),
        isError: true,
      );
    }
  }

  Future<void> _deleteComment(int index) async {
    final comment = _comments[index];
    final commentId = comment.id;
    final entityId = widget.item.entityId;
    if (commentId == null || entityId == null) return;

    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.tr('comment.delete_title'),
      content: context.tr('comment.delete_confirm'),
      buttonText: context.tr('common.delete'),
      secondaryButtonText: context.tr('common.cancel'),
      showCloseIcon: false,
    );
    if (confirmed != true) return;

    setState(() {
      _comments.removeAt(index);
      _syncCommentCount();
    });
    try {
      if (widget.item.source == FeedSource.news) {
        await NewsRepository.instance.deleteComment(entityId, commentId);
      } else {
        await ItemPostRepository.instance.deleteComment(entityId, commentId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments.insert(index, comment);
        _syncCommentCount();
      });
      AppDialog.showToast(
        context,
        context.tr('comment.delete_failed'),
        isError: true,
      );
    }
  }

  Widget _buildDefaultAvatar(String authorName) {
    if (authorName.toLowerCase().contains('super admin')) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Image.asset(
          'assets/images/super_admin.png',
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Image.asset(
          'assets/images/logo_3d.png',
          cacheWidth: 80,
          fit: BoxFit.cover,
        ),
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
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.item.authorAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.item.authorAvatar,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => _buildDefaultAvatar(widget.item.authorName),
                          )
                        : _buildDefaultAvatar(widget.item.authorName),
                  ),
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
                              PageRouteBuilder(
                                opaque: false,
                                transitionDuration: const Duration(milliseconds: 300),
                                reverseTransitionDuration: Duration.zero,
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                imageUrl: widget.item.imageUrls[0],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
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
                        height: 210,
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
                                  PageRouteBuilder(
                                    opaque: false,
                                    transitionDuration: const Duration(milliseconds: 300),
                                    reverseTransitionDuration: Duration.zero,
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
                                margin: const EdgeInsets.only(right: 12),
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
                          onTap: _focusCommentIfSignedIn,
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.chatCircle,
                                color: Colors.black87,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatCount(_displayCommentCount),
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
                        ],
                      ),
                    ),
                    if (comment.isMine && comment.id != null)
                      SizedBox(
                        height: 24,
                        width: 28,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: Colors.black45,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') _editComment(index);
                            if (value == 'delete') _deleteComment(index);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(context.tr('common.edit')),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                context.tr('common.delete'),
                                style: const TextStyle(color: Colors.red),
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
          ],
        ),
      ),
    );
  }
}

