import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

/// A lightweight local chat message used by the in-app chat preview.
///
/// There is no backend yet, so messages live only in memory for the lifetime
/// of this screen. Image/attachment sending is intentionally not supported.
class _ChatMessage {
  final String text;
  final bool isMine;
  final DateTime sentAt;

  const _ChatMessage({
    required this.text,
    required this.isMine,
    required this.sentAt,
  });
}

/// Chat UI used in the order flow (restaurant / delivery rider).
///
/// This is a front-end-only preview: messages the user sends are appended to
/// the on-screen conversation but are not delivered anywhere because the chat
/// backend is not ready yet. Sending images is not allowed for now.
class ChatPage extends StatefulWidget {
  final String peerName;
  final String peerSubtitle;
  final String? avatarUrl;
  final IconData fallbackIcon;

  const ChatPage({
    super.key,
    required this.peerName,
    required this.peerSubtitle,
    this.avatarUrl,
    this.fallbackIcon = Icons.storefront_rounded,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_ChatMessage> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(text: text, isMine: true, sentAt: DateTime.now()),
      );
      _controller.clear();
    });

    // Keep the latest message in view after the list rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    widget.peerSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildPreviewNotice(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildBubble(context, _messages[index]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = widget.avatarUrl;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _buildAvatarFallback(),
            )
          : _buildAvatarFallback(),
    );
  }

  Widget _buildAvatarFallback() {
    return Center(
      child: Icon(widget.fallbackIcon, size: 20, color: AppColors.primary),
    );
  }

  Widget _buildPreviewNotice() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('chat.preview_notice'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.amber[900],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.chatCircleTextFill,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('chat.empty_title'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('chat.empty_sub'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, _ChatMessage message) {
    final isMine = message.isMine;
    final timeLabel = TimeOfDay.fromDateTime(message.sentAt).format(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMine ? AppColors.primaryGradient : null,
              color: isMine ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
              border: isMine
                  ? null
                  : Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.4,
                color: isMine ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              timeLabel,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: context.tr('chat.input_hint'),
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

