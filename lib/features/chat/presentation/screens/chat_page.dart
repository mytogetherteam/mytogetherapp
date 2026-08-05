import 'dart:async';

import 'package:any_link_preview/any_link_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/network/websocket_service.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/time_formatter.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_model.dart';
import 'package:mytogetherapp/features/chat/data/models/chat_window.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_service.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_unread_controller.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_voice_recorder.dart';
import 'package:mytogetherapp/features/chat/presentation/widgets/audio_message_bubble.dart';
import 'package:mytogetherapp/features/chat/presentation/widgets/floating_chat_head.dart';
import 'package:mytogetherapp/features/chat/presentation/widgets/voice_record_button.dart';
import 'package:mytogetherapp/app.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Order-scoped chat screen wired to `user/chat` REST + `/user/queue/chat-updates`.
///
/// Conversations are keyed by [orderId] on the backend — shop and rider chat
/// buttons both open this same thread for the active order.
class ChatPage extends StatefulWidget {
  final int orderId;
  final String peerName;
  final String peerSubtitle;
  final String? avatarUrl;
  final IconData fallbackIcon;

  const ChatPage({
    super.key,
    required this.orderId,
    required this.peerName,
    required this.peerSubtitle,
    this.avatarUrl,
    this.fallbackIcon = Icons.storefront_rounded,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with RouteAware, WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final ChatVoiceRecorder _voiceRecorder = ChatVoiceRecorder();

  late int _conversationId;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isSending = false;
  bool _isLoadingOlder = false;
  bool _isChatClosed = false;
  int _currentPage = 1;
  int _lastPage = 1;

  StreamSubscription<Map<String, dynamic>>? _chatSub;
  StreamSubscription<Map<String, dynamic>>? _orderSub;
  Timer? _chatWindowTimer;
  Timer? _countdownTicker;
  DateTime? _chatClosesAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationId = 0;
    WebSocketService().connect();
    _scrollController.addListener(_onScroll);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _chatSub = WebSocketService().chatUpdates.listen(_onChatEvent);
    _orderSub = WebSocketService().orderUpdates.listen(_onOrderEvent);
    // Opening a thread marks the shop's messages as read; clear its badge.
    ChatUnreadController.instance.start();
    ChatUnreadController.instance.clear(widget.orderId);

    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      App.routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    // Entered ChatPage -> Hide chat head
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = true);
  }

  @override
  void didPopNext() {
    // Returned to ChatPage -> Hide chat head
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = true);
  }

  @override
  void didPushNext() {
    // Opened another page from ChatPage -> Show chat head
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = false);
  }

  @override
  void didPop() {
    // Exited ChatPage -> Show chat head
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshChatWindow();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _voiceRecorder.cancel();
    }
  }

  @override
  void dispose() {
    App.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _voiceRecorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _chatSub?.cancel();
    _orderSub?.cancel();
    _chatWindowTimer?.cancel();
    _countdownTicker?.cancel();
    // Anything received while the thread was open has now been seen.
    ChatUnreadController.instance.clear(widget.orderId);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final conversation = await ChatService.instance.getConversationByOrder(
      widget.orderId,
    );

    if (!mounted) return;

    if (conversation != null) {
      _conversationId = conversation.id;
      _isChatClosed = !conversation.isChatWritable;
      _setChatWindow(
        status: conversation.orderStatus,
        orderUpdatedAt: conversation.orderUpdatedAt,
      );
      if (_conversationId > 0) {
        await ChatService.instance.markAsRead(_conversationId);
        ChatUnreadController.instance.clear(widget.orderId);
        await _loadMessages();
        return;
      }
    }

    setState(() {
      _isLoading = false;
      _hasError = false;
    });
  }

  void _onOrderEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    Map<String, dynamic> order = event;
    if (event['order'] is Map) {
      order = Map<String, dynamic>.from(event['order'] as Map);
    } else if (event['data'] is Map) {
      order = Map<String, dynamic>.from(event['data'] as Map);
    }

    final orderId =
        (order['id'] as num?)?.toInt() ?? (event['orderId'] as num?)?.toInt();
    if (orderId != widget.orderId) return;

    _setChatWindow(
      status: order['status']?.toString(),
      orderUpdatedAt: DateTime.tryParse(
        order['updatedAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }

  void _setChatWindow({
    required String? status,
    required DateTime? orderUpdatedAt,
  }) {
    _chatWindowTimer?.cancel();
    _countdownTicker?.cancel();
    final normalized = status?.toUpperCase();

    if (normalized == 'CANCELED' || normalized == 'CANCELLED') {
      _chatClosesAt = null;
      if (mounted) setState(() => _isChatClosed = true);
      return;
    }

    if ((normalized != 'DELIVERED' && normalized != 'PICKED_UP') ||
        orderUpdatedAt == null) {
      _chatClosesAt = null;
      return;
    }

    _chatClosesAt = ChatWindow.closesAt(normalized, orderUpdatedAt);
    _refreshChatWindow();
  }

  void _refreshChatWindow() {
    _chatWindowTimer?.cancel();
    _countdownTicker?.cancel();
    final closesAt = _chatClosesAt;
    if (closesAt == null || !mounted) return;

    final remaining = closesAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      setState(() => _isChatClosed = true);
      return;
    }

    setState(() => _isChatClosed = false);
    _countdownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _chatWindowTimer = Timer(remaining, () {
      _countdownTicker?.cancel();
      if (mounted) setState(() => _isChatClosed = true);
    });
  }

  String get _headerSubtitle {
    if (_isChatClosed) return context.tr('chat.closed_title');
    final timeLeft = ChatWindow.compactTimeLeft(_chatClosesAt);
    if (timeLeft.isEmpty) return widget.peerSubtitle;
    return context.trArgs('chat.support_subtitle', {'time': timeLeft});
  }

  Future<void> _loadMessages() async {
    if (_conversationId <= 0) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final result = await ChatService.instance.getMessages(_conversationId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result == null) {
        _hasError = true;
      } else {
        _hasError = false;
        _messages
          ..clear()
          ..addAll(result.items.reversed);
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _loadOlder() async {
    if (_isLoadingOlder || _currentPage >= _lastPage || _conversationId <= 0) {
      return;
    }
    setState(() => _isLoadingOlder = true);

    final result = await ChatService.instance.getMessages(
      _conversationId,
      page: _currentPage + 1,
    );
    if (!mounted) return;

    setState(() {
      _isLoadingOlder = false;
      if (result != null) {
        _messages.insertAll(0, result.items.reversed);
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 80 &&
        !_isLoadingOlder &&
        _currentPage < _lastPage) {
      _loadOlder();
    }
  }

  void _onChatEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = event['type'] as String?;
    if (type == 'CHAT_CONVERSATION_HIDDEN') {
      final orderId = (event['orderId'] as num?)?.toInt();
      if (orderId == widget.orderId) {
        setState(() => _isChatClosed = true);
      }
      return;
    }

    // The shop read this conversation → flip our sent messages to ✅✅.
    if (type == 'CONVERSATION_READ') {
      final orderId = (event['orderId'] as num?)?.toInt();
      final conversationId = (event['conversationId'] as num?)?.toInt();
      final matchesOrder = orderId == null || orderId == widget.orderId;
      final matchesConversation =
          conversationId == null ||
          _conversationId <= 0 ||
          conversationId == _conversationId;
      if (!matchesOrder || !matchesConversation) return;
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          if (m.isMe && !m.isRead) {
            _messages[i] = m.copyWith(isRead: true);
          }
        }
      });
      return;
    }

    if (_conversationId <= 0) {
      final conversationId = (event['conversationId'] as num?)?.toInt();
      if (conversationId != null) _conversationId = conversationId;
    } else {
      final conversationId = (event['conversationId'] as num?)?.toInt();
      if (conversationId != null && conversationId != _conversationId) return;
    }

    final raw = (event['message'] as Map?)?.cast<String, dynamic>();
    if (raw == null) return;
    final incoming = ChatMessage.fromJson(raw);

    setState(() {
      final index = _messages.indexWhere((m) => m.id == incoming.id);
      switch (type) {
        case 'CHAT_MESSAGE':
          if (index == -1) {
            _messages.add(incoming);
          } else {
            _messages[index] = incoming;
          }
          break;
        case 'CHAT_MESSAGE_EDIT':
        case 'CHAT_MESSAGE_DELETE':
          if (index != -1) _messages[index] = incoming;
          break;
      }
    });

    if (type == 'CHAT_MESSAGE' && _isNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        120;
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending || _isChatClosed) return;

    _controller.clear();
    setState(() => _isSending = true);

    final sent = await ChatService.instance.sendTextMessage(
      widget.orderId,
      text,
    );
    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (sent != null) {
        if (_conversationId <= 0 && sent.conversationId != null) {
          _conversationId = sent.conversationId!;
        }
        final index = _messages.indexWhere((m) => m.id == sent.id);
        if (index == -1) {
          _messages.add(sent);
        } else {
          _messages[index] = sent;
        }
      }
    });

    if (sent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      _controller.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('chat.send_failed'))));
    }
  }

  Future<void> _sendVoiceMessage(VoiceRecordingResult result) async {
    if (_isSending || _isChatClosed) {
      await ChatVoiceRecorder.deleteFile(result.path);
      return;
    }

    setState(() => _isSending = true);
    final sent = await ChatService.instance.sendVoiceMessage(
      widget.orderId,
      result.path,
      durationSeconds: result.durationSeconds,
    );
    await ChatVoiceRecorder.deleteFile(result.path);
    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (sent != null) {
        if (_conversationId <= 0 && sent.conversationId != null) {
          _conversationId = sent.conversationId!;
        }
        final index = _messages.indexWhere((m) => m.id == sent.id);
        if (index == -1) {
          _messages.add(sent);
        } else {
          _messages[index] = sent;
        }
      }
    });

    if (sent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('chat.send_failed'))));
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    if (_conversationId <= 0) return;
    final editController = TextEditingController(text: message.content ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('chat.edit_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, editController.text.trim()),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == message.content) return;

    final updated = await ChatService.instance.editMessage(
      _conversationId,
      message.id,
      result,
    );
    if (!mounted || updated == null) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) _messages[index] = updated;
    });
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    if (_conversationId <= 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('chat.delete_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(context.tr('chat.delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr('common.delete'),
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ChatService.instance.deleteMessage(
      _conversationId,
      message.id,
    );
    if (!mounted || !ok) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = message.copyWith(isDeleted: true, content: '');
      }
    });
  }

  void _showMessageActions(ChatMessage message) {
    if (message.isDeleted) return;

    // Extract links
    final urlRegExp = RegExp(
      r'(?:(?:https?|ftp)://)?[\w/\-?=%.]+\.[\w/\-?=%.]+',
    );
    final matches = urlRegExp.allMatches(message.content ?? '');
    final urls = matches.map((m) => m.group(0)!).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.kind == ChatMessageKind.text)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(
                  context.tr('common.copy') == 'common.copy'
                      ? 'Copy Text'
                      : context.tr('common.copy'),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content ?? ''));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr('chat.copied') == 'chat.copied'
                            ? 'Copied to clipboard'
                            : context.tr('chat.copied'),
                      ),
                    ),
                  );
                },
              ),
            for (var url in urls)
              ListTile(
                leading: const Icon(Icons.open_in_browser_rounded),
                title: Text(
                  'Open link: $url',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                    url.startsWith('http') ? url : 'https://$url',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            if (message.isMe && message.kind == ChatMessageKind.text)
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(context.tr('chat.edit_title')),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(message);
                },
              ),
            if (message.isMe)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: Text(
                  context.tr('chat.delete_title'),
                  style: const TextStyle(color: Color(0xFFEF4444)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
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
                    _headerSubtitle,
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
          Expanded(
            child: _isLoading
                ? const Center(child: CustomLoadingIndicator())
                : _hasError
                ? _buildErrorState()
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: _messages.length + (_isLoadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoadingOlder && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: CustomLoadingIndicator(size: 20),
                          ),
                        );
                      }
                      final msgIndex = _isLoadingOlder ? index - 1 : index;
                      return _buildBubble(context, _messages[msgIndex]);
                    },
                  ),
          ),
          if (_isChatClosed) _buildClosedOrderAlert() else _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildClosedOrderAlert() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('chat.closed_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('chat.closed_body'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.tr('chat.load_failed'),
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _conversationId > 0 ? _loadMessages : _bootstrap,
            child: Text(context.tr('common.retry')),
          ),
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
          ? CachedNetworkImage(
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
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

  Widget _buildBubble(BuildContext context, ChatMessage message) {
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Text(
            context.tr('chat.message_deleted'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[500],
            ),
          ),
        ),
      );
    }

    final isMine = message.isMe;
    final timeLabel = TimeFormatter.formatClock(message.createdAt);
    final displayText = message.kind == ChatMessageKind.image
        ? '📷 ${context.tr('chat.photo')}'
        : message.isVoice
        ? '🎤 ${context.tr('chat.voice')}'
        : (message.content ?? '');

    final urlRegExp = RegExp(
      r'(?:(?:https?|ftp)://)?[\w/\-?=%.]+\.[\w/\-?=%.]+',
    );
    final urls = urlRegExp
        .allMatches(displayText)
        .map((m) => m.group(0)!)
        .toList();
    final firstUrl = urls.isNotEmpty ? urls.first : null;
    final voiceUrl = message.voiceUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
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
                border: isMine ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: message.isVoice && voiceUrl != null && voiceUrl.isNotEmpty
                  ? AudioMessageBubble(
                      url: voiceUrl,
                      durationSeconds: message.voiceDurationSeconds,
                      isMine: isMine,
                      foreground: isMine
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      background: Colors.transparent,
                    )
                  : Text(
                      displayText,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.4,
                        color: isMine ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
            ),
            if (firstUrl != null)
              FutureBuilder(
                future: AnyLinkPreview.getMetadata(
                  link: firstUrl.startsWith('http')
                      ? firstUrl
                      : 'https://$firstUrl',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  final metadata = snapshot.data;
                  if (metadata == null ||
                      metadata.image == null ||
                      metadata.image!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    child: AnyLinkPreview(
                      link: firstUrl.startsWith('http')
                          ? firstUrl
                          : 'https://$firstUrl',
                      displayDirection: UIDirection.uiDirectionHorizontal,
                      cache: const Duration(hours: 1),
                      backgroundColor: Colors.white,
                      errorWidget: const SizedBox.shrink(),
                      borderRadius: 12,
                    ),
                  );
                },
              ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.isEdited
                        ? '$timeLabel · ${context.tr('chat.edited')}'
                        : timeLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                  // Read receipt for the user's own messages: a single check
                  // once sent, a double (coloured) check once the shop reads it.
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: message.isRead
                          ? AppColors.primary
                          : Colors.grey[400],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final hasText = _controller.text.trim().isNotEmpty;
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
        child: ValueListenableBuilder<VoiceRecordPhase>(
          valueListenable: _voiceRecorder.phaseNotifier,
          builder: (context, phase, _) {
            final recording = phase != VoiceRecordPhase.idle;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Messenger-style: recording replaces the text box entirely.
                Expanded(
                  child: recording
                      ? VoiceRecordingStrip(
                          recorder: _voiceRecorder,
                          isBusy: _isSending,
                          onSend: _sendVoiceMessage,
                        )
                      : Container(
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
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                if (hasText && !recording)
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _isSending ? null : AppColors.primaryGradient,
                        color: _isSending ? Colors.grey[300] : null,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  )
                else
                  VoiceRecordButton(
                    recorder: _voiceRecorder,
                    enabled: !_isSending && !_isChatClosed,
                    isBusy: _isSending,
                    onSend: _sendVoiceMessage,
                    onPermissionDenied: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('chat.mic_permission')),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
