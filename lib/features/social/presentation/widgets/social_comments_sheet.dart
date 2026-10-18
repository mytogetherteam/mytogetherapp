import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/models/post_dto.dart';
import '../../data/repositories/social_posts_repository.dart';

Future<int?> showSocialCommentsSheet({
  required BuildContext context,
  required SocialPostDto post,
  void Function(SocialPostAuthorDto author)? onAuthorTap,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SocialCommentsSheet(
      post: post,
      onAuthorTap: onAuthorTap,
    ),
  );
}

class _SocialCommentsSheet extends StatefulWidget {
  final SocialPostDto post;
  final void Function(SocialPostAuthorDto author)? onAuthorTap;

  const _SocialCommentsSheet({
    required this.post,
    this.onAuthorTap,
  });

  @override
  State<_SocialCommentsSheet> createState() => _SocialCommentsSheetState();
}

class _SocialCommentsSheetState extends State<_SocialCommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SocialPostCommentDto> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  SocialPostCommentDto? _replyTo;
  final _commentLikesInFlight = <int>{};

  int get _myUserId => AuthService().currentUser?.id ?? -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items =
          await SocialPostsRepository.instance.fetchComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = items;
        _loading = false;
        // The feed count includes replies. A short page must not replace it.
        var loaded = 0;
        for (final item in items) {
          final replies = item.replyCount > item.replies.length
              ? item.replyCount
              : item.replies.length;
          loaded += 1 + replies;
        }
        if (loaded > widget.post.commentCount) {
          widget.post.commentCount = loaded;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr('social.comments_load_failed');
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final parent = _replyTo;
      final created = await SocialPostsRepository.instance.addComment(
        widget.post.id,
        text,
        parentId: parent?.id,
      );
      if (!mounted) return;
      if (created != null) {
        setState(() {
          if (parent != null) {
            final rootId = parent.parentId ?? parent.id;
            final root = _comments.cast<SocialPostCommentDto?>().firstWhere(
                  (comment) => comment?.id == rootId,
                  orElse: () => null,
                );
            root?.replies.add(created);
            if (root != null) root.replyCount += 1;
          } else {
            _comments = [created, ..._comments];
          }
          widget.post.commentCount += 1;
          _controller.clear();
          _replyTo = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('social.comment_failed'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(
    SocialPostCommentDto comment, {
    SocialPostCommentDto? parent,
  }) async {
    try {
      await SocialPostsRepository.instance.deleteComment(
        widget.post.id,
        comment.id,
      );
      if (!mounted) return;
      setState(() {
        final replyTotal = comment.replyCount > comment.replies.length
            ? comment.replyCount
            : comment.replies.length;
        final removed = parent == null ? 1 + replyTotal : 1;
        if (parent == null) {
          _comments = _comments.where((c) => c.id != comment.id).toList();
          if (_replyTo?.id == comment.id || _replyTo?.parentId == comment.id) {
            _replyTo = null;
          }
        } else {
          parent.replies.removeWhere((reply) => reply.id == comment.id);
          if (parent.replyCount > 0) parent.replyCount -= 1;
          if (_replyTo?.id == comment.id) _replyTo = null;
        }
        widget.post.commentCount =
            (widget.post.commentCount - removed).clamp(0, 1 << 30);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('social.comment_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final available = media.size.height - keyboard - media.padding.top - 12;
    final preferred = media.size.height * 0.68;
    final height = available < preferred
        ? available.clamp(0.0, preferred)
        : preferred;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.post.commentCount <= 0
                          ? context.tr('social.comments_title')
                          : '${context.tr('social.comments_title')} · ${widget.post.commentCount}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context, widget.post.commentCount),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(child: _buildBody()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            TextButton(onPressed: _load, child: Text(context.tr('social.retry'))),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          context.tr('social.no_comments'),
          style: GoogleFonts.poppins(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final c = _comments[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _commentRow(c),
            for (final reply in c.replies)
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 12),
                child: _commentRow(reply, parent: c),
              ),
            if (c.replyCount > c.replies.length)
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 8),
                child: Text(
                  '${c.replyCount - c.replies.length} ${context.tr('social.more_replies')}',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _startReply(SocialPostCommentDto root) {
    setState(() => _replyTo = root);
    _focusNode.requestFocus();
  }

  Future<void> _toggleCommentLike(SocialPostCommentDto comment) async {
    if (!_commentLikesInFlight.add(comment.id)) return;
    final wasLiked = comment.likedByMe;
    final wasCount = comment.likeCount;
    setState(() {
      comment.likedByMe = !wasLiked;
      comment.likeCount = (wasCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
    });
    try {
      final result = await SocialPostsRepository.instance.toggleCommentLike(
        widget.post.id,
        comment.id,
      );
      if (!mounted) return;
      setState(() {
        comment.likedByMe = result.liked;
        comment.likeCount = result.likeCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        comment.likedByMe = wasLiked;
        comment.likeCount = wasCount;
      });
    } finally {
      _commentLikesInFlight.remove(comment.id);
    }
  }

  Widget _commentRow(
    SocialPostCommentDto c, {
    SocialPostCommentDto? parent,
  }) {
    final mine = c.isMine(_myUserId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onAuthorTap == null
              ? null
              : () => widget.onAuthorTap!(c.author),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 4, 2),
            child: CircleAvatar(
            radius: parent == null ? 16 : 13,
            backgroundColor: Colors.transparent,
            backgroundImage: (c.author.avatarUrl?.isNotEmpty == true)
                ? CachedNetworkImageProvider(c.author.avatarUrl!)
                : null,
            child: (c.author.avatarUrl?.isNotEmpty == true)
                ? null
                : _buildCommentAvatarFallback(c.author),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onAuthorTap == null
                    ? null
                    : () => widget.onAuthorTap!(c.author),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    c.author.displayName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                c.content,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    c.timeAgo,
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _startReply(c),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        context.tr('social.reply'),
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            GestureDetector(
              onTap: () => _toggleCommentLike(c),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  c.likedByMe ? PhosphorIcons.heartFill : PhosphorIcons.heart,
                  size: 16,
                  color: c.likedByMe ? AppColors.primary : Colors.white54,
                ),
              ),
            ),
            if (c.likeCount > 0)
              Text(
                '${c.likeCount}',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
              ),
            if (mine)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(c, parent: parent),
                icon: const Icon(
                  PhosphorIcons.trash,
                  size: 16,
                  color: Colors.white38,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${context.tr('social.replying_to')} ${_replyTo!.author.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyTo = null),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close, color: Colors.white54, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: context.tr('social.add_comment'),
                  hintStyle: GoogleFonts.poppins(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  : const Icon(PhosphorIcons.paperPlaneRightFill,
                      color: AppColors.primary),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentAvatarFallback(SocialPostAuthorDto author) {
    if (author.type == SocialAuthorType.admin ||
        author.displayName.toLowerCase().contains('super admin')) {
      return Image.asset(
        'assets/images/super_admin.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(PhosphorIcons.shieldCheck, size: 16, color: Colors.white),
      );
    }
    if (author.type == SocialAuthorType.shop) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
        ),
        alignment: Alignment.center,
        child: const Icon(PhosphorIcons.storefront, size: 16, color: Colors.white),
      );
    }
    final clean =
        author.displayName.replaceAll(RegExp(r'^[@\s\-_.]+'), '').trim();
    final initial = clean.isNotEmpty ? clean.characters.first.toUpperCase() : 'U';

    int hash = 0;
    for (final unit in author.displayName.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    const gradients = [
      [Color(0xFFFF5E62), Color(0xFFFF9966)],
      [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      [Color(0xFF00C6FF), Color(0xFF0072FF)],
      [Color(0xFFF857A6), Color(0xFFFF5858)],
      [Color(0xFF11998E), Color(0xFF38EF7D)],
      [Color(0xFFFF8008), Color(0xFFFFC837)],
      [Color(0xFF654EA3), Color(0xFFEAAFC8)],
      [Color(0xFF1D976C), Color(0xFF93F9B9)],
      [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
      [Color(0xFF2193B0), Color(0xFF6DD5ED)],
      [Color(0xFFDA22FF), Color(0xFF9733EE)],
      [Color(0xFFFA709A), Color(0xFFFEE140)],
    ];
    final colors = gradients[hash % gradients.length];

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

