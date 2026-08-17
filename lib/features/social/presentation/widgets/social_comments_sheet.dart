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
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SocialCommentsSheet(post: post),
  );
}

class _SocialCommentsSheet extends StatefulWidget {
  final SocialPostDto post;

  const _SocialCommentsSheet({required this.post});

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
        // Keep the higher of feed count vs loaded page (page may be capped at 50).
        if (items.length > widget.post.commentCount) {
          widget.post.commentCount = items.length;
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
      final created = await SocialPostsRepository.instance.addComment(
        widget.post.id,
        text,
      );
      if (!mounted) return;
      if (created != null) {
        setState(() {
          _comments = [created, ..._comments];
          widget.post.commentCount = _comments.length;
          _controller.clear();
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

  Future<void> _delete(SocialPostCommentDto comment) async {
    try {
      await SocialPostsRepository.instance.deleteComment(
        widget.post.id,
        comment.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((c) => c.id != comment.id).toList();
        widget.post.commentCount = _comments.length;
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.68,
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
                      context.tr('social.comments_title'),
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
        final mine = c.isMine(_myUserId);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.4),
              backgroundImage: (c.author.avatarUrl?.isNotEmpty == true)
                  ? CachedNetworkImageProvider(c.author.avatarUrl!)
                  : null,
              child: (c.author.avatarUrl?.isNotEmpty == true)
                  ? null
                  : const Icon(PhosphorIcons.user, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.author.displayName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
                  Text(
                    c.timeAgo,
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (mine)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(c),
                icon: const Icon(
                  PhosphorIcons.trash,
                  size: 18,
                  color: Colors.white38,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
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
      ),
    );
  }
}
