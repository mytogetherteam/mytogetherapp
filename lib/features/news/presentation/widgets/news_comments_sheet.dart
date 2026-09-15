import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import '../../data/models/news_comment.dart';
import '../../data/models/news_item.dart';
import '../../data/repositories/news_repository.dart';
import '../../../lost_and_found/data/repositories/item_post_repository.dart';

Future<int?> showNewsCommentsSheet({
  required BuildContext context,
  required NewsItem item,
  bool autoFocus = false,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => NewsCommentsSheet(
      item: item,
      autoFocus: autoFocus,
    ),
  );
}

class NewsCommentsSheet extends StatefulWidget {
  final NewsItem item;
  final bool autoFocus;

  const NewsCommentsSheet({
    super.key,
    required this.item,
    this.autoFocus = false,
  });

  @override
  State<NewsCommentsSheet> createState() => _NewsCommentsSheetState();
}

class _NewsCommentsSheetState extends State<NewsCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  List<NewsComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  int get _myUserId => AuthService().currentUser?.id ?? -1;

  @override
  void initState() {
    super.initState();
    _loadComments();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final id = widget.item.entityId;
    if (id == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

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
                  isMine: _myUserId != -1 &&
                      (c.userId == _myUserId || c.user?.id == _myUserId),
                ),
              )
              .toList();
          _loading = false;
          widget.item.commentsCount = _comments.length;
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
                  isMine: _myUserId != -1 && c.user?.id == _myUserId,
                ),
              )
              .toList();
          _loading = false;
          widget.item.commentsCount = _comments.length;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr('social.comments_load_failed');
      });
    }
  }

  Future<void> _postComment() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;

    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    if (widget.item.isApiBacked && widget.item.entityId != null) {
      final entityId = widget.item.entityId!;
      try {
        if (widget.item.source == FeedSource.news) {
          final created = await NewsRepository.instance.addComment(
            entityId,
            text,
          );
          if (!mounted) return;
          if (created != null) {
            AppHaptics.buttonTap();
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
              widget.item.commentsCount = _comments.length;
              _commentController.clear();
            });
          }
        } else if (widget.item.source == FeedSource.itemPost) {
          final created = await ItemPostRepository.instance.addComment(
            entityId,
            text,
          );
          if (!mounted) return;
          if (created != null) {
            AppHaptics.buttonTap();
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
              widget.item.commentsCount = _comments.length;
              _commentController.clear();
            });
          }
        }
      } catch (_) {
        if (!mounted) return;
        AppDialog.showToast(
          context,
          context.tr('social.comment_failed'),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    // Fallback for non-API backed
    setState(() {
      _comments.insert(
        0,
        NewsComment(
          authorName: context.tr('news.you'),
          authorAvatar: '',
          content: text,
          timeAgo: context.tr('common.just_now'),
          isMine: true,
        ),
      );
      widget.item.commentsCount = _comments.length;
      _commentController.clear();
      _sending = false;
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
      widget.item.commentsCount = _comments.length;
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
        widget.item.commentsCount = _comments.length;
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
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Image.asset(
          'assets/images/super_admin.png',
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
              child: Row(
                children: [
                  Text(
                    context.tr('news.comments'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_comments.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context, widget.item.commentsCount),
                    icon: const Icon(Icons.close, color: Colors.black54, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            // Body
            Expanded(child: _buildBody()),
            // Sticky Composer
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CustomLoadingIndicator(size: 32));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadComments,
              child: Text(context.tr('social.retry')),
            ),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.chatCircleDots,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('social.no_comments'),
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => const Divider(
        height: 16,
        thickness: 0.5,
        color: Color(0xFFF0F0F0),
      ),
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: comment.authorAvatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: comment.authorAvatar,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) =>
                            _buildDefaultAvatar(comment.authorName),
                      )
                    : _buildDefaultAvatar(comment.authorName),
              ),
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
        );
      },
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
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
      child: Row(
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
                autofocus: widget.autoFocus,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _postComment(),
                decoration: InputDecoration(
                  hintText: context.tr('news.add_comment'),
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sending ? null : _postComment,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      PhosphorIcons.paperPlaneRightFill,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
