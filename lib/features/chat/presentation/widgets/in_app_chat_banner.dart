import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/app.dart';
import 'package:mytogetherapp/core/network/websocket_service.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:mytogetherapp/core/utils/file_url_util.dart';
import 'package:mytogetherapp/features/cart/data/active_order_state.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_unread_controller.dart';
import 'package:mytogetherapp/features/chat/presentation/screens/chat_page.dart';
import 'package:mytogetherapp/features/search/data/search_repository.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Messenger-style floating in-app notification banner that drops down from the top
/// when an incoming chat message arrives while the user is actively using the app.
class InAppChatBanner {
  InAppChatBanner._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;
  static StreamSubscription<Map<String, dynamic>>? _chatSub;
  static bool _initialized = false;

  /// Cache of recently handled message IDs or hashes to prevent double banners (FCM + WebSocket).
  static final Set<String> _recentMessageKeys = <String>{};

  /// In-memory cache of shop logos and names keyed by orderId or shopId.
  static final Map<int, ({String? name, String? logoUrl})> _shopCache = {};

  static void cacheShopInfo(int id, {String? name, String? logoUrl}) {
    if (id <= 0) return;
    final existing = _shopCache[id];
    _shopCache[id] = (
      name: name ?? existing?.name,
      logoUrl: logoUrl ?? existing?.logoUrl,
    );
  }

  /// Initializes the in-app chat banner listener on realtime WebSocket events.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    ChatUnreadController.instance.start();
    _chatSub = WebSocketService().chatUpdates.listen(_onWebSocketChatEvent);
  }

  static void dispose() {
    _chatSub?.cancel();
    _chatSub = null;
    _initialized = false;
  }

  static void _onWebSocketChatEvent(Map<String, dynamic> event) {
    try {
      final type = event['type'] as String?;
      if (type != 'CHAT_MESSAGE') return;

      final raw = (event['message'] as Map?)?.cast<String, dynamic>();
      if (raw == null) return;

      final senderRole = raw['senderRole']?.toString().toUpperCase() ??
          raw['senderType']?.toString().toUpperCase();
      if (senderRole == 'USER') {
        // Our own sent message — never show banner
        return;
      }

      final orderId = (event['orderId'] as num?)?.toInt() ??
          (raw['orderId'] as num?)?.toInt();
      if (orderId == null) return;

      // If user is actively chatting inside this conversation, do not show banner
      if (ChatPage.activeOrderId == orderId) return;

      final messageId = raw['id']?.toString() ?? '';
      final content = raw['content']?.toString() ?? '';
      final dedupKey = messageId.isNotEmpty ? messageId : '${orderId}_$content';
      if (_isDuplicate(dedupKey)) return;

      final rawSenderName = raw['senderName']?.toString() ??
          raw['sender_name']?.toString() ??
          event['shopName']?.toString() ??
          event['shop_name']?.toString() ??
          event['peerName']?.toString() ??
          '';

      final rawSenderAvatar = raw['senderAvatarUrl']?.toString() ??
          raw['senderAvatar']?.toString() ??
          raw['avatarUrl']?.toString() ??
          event['shopAvatar']?.toString() ??
          event['peerAvatar']?.toString() ??
          event['shopLogo']?.toString() ??
          event['shop_logo']?.toString() ??
          event['logoPath']?.toString() ??
          event['logo_path']?.toString();

      final kind = raw['kind']?.toString().toUpperCase() ??
          raw['type']?.toString().toUpperCase();
      String rawText = content;
      if (kind == 'VOICE') {
        rawText = '🎤 Voice message';
      } else if (kind == 'IMAGE') {
        rawText = '📷 Photo';
      }

      final cleanData = _resolveCleanChatData(
        orderId: orderId,
        rawSenderName: rawSenderName,
        rawMessageText: rawText,
        rawAvatarUrl: rawSenderAvatar,
      );

      show(
        orderId: orderId,
        senderName: cleanData.shopName,
        messageText: cleanData.cleanMessage,
        avatarUrl: cleanData.logoUrl,
      );
    } catch (_) {}
  }

  /// Triggers the banner from an FCM RemoteMessage when received in the foreground.
  static void showFromRemoteMessage(RemoteMessage message) {
    try {
      final orderIdStr = message.data['orderId']?.toString() ??
          message.data['order_id']?.toString() ??
          message.data['referenceId']?.toString();
      final orderId = orderIdStr != null ? int.tryParse(orderIdStr) : null;
      if (orderId == null) return;

      // If user is actively chatting inside this conversation, do not show banner
      if (ChatPage.activeOrderId == orderId) return;

      final messageId = message.data['messageId']?.toString() ??
          message.data['id']?.toString() ??
          message.messageId ??
          '';
      final content = message.notification?.body ??
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          message.data['content']?.toString() ??
          'New message';

      final dedupKey = messageId.isNotEmpty ? messageId : '${orderId}_$content';
      if (_isDuplicate(dedupKey)) return;

      final rawSenderName = message.data['senderName']?.toString() ??
          message.data['sender_name']?.toString() ??
          message.data['shopName']?.toString() ??
          message.data['shop_name']?.toString() ??
          message.data['restaurantName']?.toString() ??
          message.data['title']?.toString() ??
          message.notification?.title ??
          '';

      final rawAvatarUrl = message.data['senderAvatar']?.toString() ??
          message.data['sender_avatar']?.toString() ??
          message.data['avatarUrl']?.toString() ??
          message.data['avatar_url']?.toString() ??
          message.data['avatar']?.toString() ??
          message.data['shopLogo']?.toString() ??
          message.data['shop_logo']?.toString() ??
          message.data['logo']?.toString() ??
          message.data['logoPath']?.toString() ??
          message.data['logo_path']?.toString() ??
          message.data['imageUrl']?.toString() ??
          message.data['image_url']?.toString() ??
          message.data['image']?.toString();

      final cleanData = _resolveCleanChatData(
        orderId: orderId,
        rawSenderName: rawSenderName,
        rawMessageText: content,
        rawAvatarUrl: rawAvatarUrl,
      );

      show(
        orderId: orderId,
        senderName: cleanData.shopName,
        messageText: cleanData.cleanMessage,
        avatarUrl: cleanData.logoUrl,
      );
    } catch (_) {}
  }

  /// Strips out order IDs and prefixes, extracts the real shop name and message,
  /// and resolves the real shop logo.
  static ({String shopName, String cleanMessage, String? logoUrl}) _resolveCleanChatData({
    required int orderId,
    required String rawSenderName,
    required String rawMessageText,
    String? rawAvatarUrl,
  }) {
    String shopName = rawSenderName.trim();
    String message = rawMessageText.trim();
    String? logo = rawAvatarUrl?.trim();

    // 1. Look for pattern: "<ShopName> (<OrderNo>): <Message>"
    // E.g.: "MyTogether Testing (ORD-20261107-0045): ff"
    final fullPattern = RegExp(
      r'^(.*?)\s*\(([A-Za-z0-9_-]*ORD[A-Za-z0-9_-]*|[0-9]+)\)\s*:\s*(.*)$',
      dotAll: true,
      caseSensitive: false,
    );
    final match = fullPattern.firstMatch(message);
    if (match != null) {
      final extractedShop = match.group(1)?.trim() ?? '';
      if (extractedShop.isNotEmpty) {
        shopName = extractedShop;
      }
      message = match.group(3)?.trim() ?? '';
    } else {
      // Check for standalone "(ORD-20261107-0045): message"
      final orderPrefixPattern = RegExp(
        r'^\s*\(([A-Za-z0-9_-]*ORD[A-Za-z0-9_-]*|[0-9]+)\)\s*:\s*(.*)$',
        dotAll: true,
        caseSensitive: false,
      );
      final orderMatch = orderPrefixPattern.firstMatch(message);
      if (orderMatch != null) {
        message = orderMatch.group(2)?.trim() ?? '';
      } else {
        // Check for "<ShopName>: <Message>"
        final shopColonPattern = RegExp(r'^(.*?)\s*:\s*(.*)$', dotAll: true);
        final sm = shopColonPattern.firstMatch(message);
        if (sm != null &&
            !sm.group(1)!.toLowerCase().startsWith('http') &&
            sm.group(1)!.length < 40) {
          final potentialShop = sm.group(1)!.trim();
          if (shopName.isEmpty ||
              shopName.toLowerCase().startsWith('new message') ||
              shopName.toLowerCase() == 'mytogether') {
            shopName = potentialShop;
            message = sm.group(2)!.trim();
          }
        }
      }
    }

    // Strip any residual "(ORD-...)" references inside message text
    message = message
        .replaceAll(
          RegExp(
            r'\s*\([A-Za-z0-9_-]*ORD[A-Za-z0-9_-]*\)\s*:?\s*',
            caseSensitive: false,
          ),
          ' ',
        )
        .trim();

    // 2. Resolve shop name from ActiveOrderState if title is generic
    final isGenericTitle = shopName.isEmpty ||
        shopName.toLowerCase().startsWith('new message') ||
        shopName.toLowerCase() == 'mytogether' ||
        shopName.toLowerCase() == 'mytogether app' ||
        shopName.toLowerCase() == 'restaurant' ||
        shopName.toLowerCase() == 'shop';

    final order = ActiveOrderState.instance.getOrder(orderId.toString());
    final stateShopName = order?.displayShopName ??
        order?.shopName ??
        order?.shopNameEn ??
        ActiveOrderState.instance.shopName ??
        _shopCache[orderId]?.name;

    if (stateShopName != null && stateShopName.trim().isNotEmpty) {
      if (isGenericTitle) {
        shopName = stateShopName.trim();
      }
    }

    // If message still starts with "ShopName:" or "ShopName :", strip it
    if (shopName.isNotEmpty) {
      final prefix = RegExp('^${RegExp.escape(shopName)}\\s*:\\s*', caseSensitive: false);
      message = message.replaceFirst(prefix, '').trim();
    }

    // 3. Resolve real shop logo
    if (logo == null || logo.isEmpty) {
      logo = order?.shopLogo ??
          order?.logoPath ??
          order?.shopImageUrl ??
          ActiveOrderState.instance.shopLogo ??
          ActiveOrderState.instance.logoPath ??
          _shopCache[orderId]?.logoUrl;
    }

    final rawShopId = order?.shopId ??
        order?.restaurantId ??
        ActiveOrderState.instance.shopId;
    final sId = int.tryParse(rawShopId ?? '');
    if ((logo == null || logo.isEmpty) && sId != null && sId > 0) {
      logo = _shopCache[sId]?.logoUrl;
      if (isGenericTitle && _shopCache[sId]?.name != null) {
        shopName = _shopCache[sId]!.name!;
      }
    }

    // Resolve URL through FileUrlUtil for absolute URL loading
    final resolvedLogo = FileUrlUtil.resolve(logo);

    if (shopName.isEmpty || shopName.toLowerCase().startsWith('new message')) {
      shopName = stateShopName ?? 'Restaurant';
    }

    return (
      shopName: shopName,
      cleanMessage: message.isEmpty ? 'New message' : message,
      logoUrl: resolvedLogo.isNotEmpty ? resolvedLogo : null,
    );
  }

  static bool _isDuplicate(String key) {
    if (key.isEmpty) return false;
    if (_recentMessageKeys.contains(key)) return true;
    _recentMessageKeys.add(key);
    Timer(const Duration(seconds: 12), () {
      _recentMessageKeys.remove(key);
    });
    return false;
  }

  /// Shows the Messenger-style top floating widget above all app screens.
  static void show({
    required int orderId,
    required String senderName,
    required String messageText,
    String? avatarUrl,
    Duration duration = const Duration(milliseconds: 4500),
  }) {
    // If the user is currently looking at this order's chat, skip the banner
    if (ChatPage.activeOrderId == orderId) return;

    final overlayState = App.navigatorKey.currentState?.overlay;
    if (overlayState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        show(
          orderId: orderId,
          senderName: senderName,
          messageText: messageText,
          avatarUrl: avatarUrl,
          duration: duration,
        );
      });
      return;
    }

    dismiss();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InAppChatBannerWidget(
        orderId: orderId,
        senderName: senderName,
        messageText: messageText,
        avatarUrl: avatarUrl,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry?.remove();
            _currentEntry = null;
          }
        },
        onTap: () {
          dismiss();
          final nav = App.navigatorKey.currentState;
          if (nav != null) {
            nav.push(
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  orderId: orderId,
                  peerName: senderName,
                  peerSubtitle: 'Restaurant',
                  avatarUrl: avatarUrl,
                ),
              ),
            );
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    HapticFeedback.lightImpact();

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  /// Dismisses the active banner immediately.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }
}

class _InAppChatBannerWidget extends StatefulWidget {
  final int orderId;
  final String senderName;
  final String messageText;
  final String? avatarUrl;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _InAppChatBannerWidget({
    required this.orderId,
    required this.senderName,
    required this.messageText,
    this.avatarUrl,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_InAppChatBannerWidget> createState() => _InAppChatBannerWidgetState();
}

class _InAppChatBannerWidgetState extends State<_InAppChatBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  double _dragOffsetY = 0.0;
  String? _resolvedAvatarUrl;
  String? _resolvedShopName;

  @override
  void initState() {
    super.initState();
    _resolvedAvatarUrl = widget.avatarUrl;
    _resolvedShopName = widget.senderName;
    _loadShopInfoIfNeeded();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _animController.forward();
  }

  Future<void> _loadShopInfoIfNeeded() async {
    final needsLogo = _resolvedAvatarUrl == null || _resolvedAvatarUrl!.isEmpty;
    final needsName = _resolvedShopName == null ||
        _resolvedShopName == 'Restaurant' ||
        _resolvedShopName!.startsWith('New message');

    if (!needsLogo && !needsName) return;

    try {
      final order = ActiveOrderState.instance.getOrder(widget.orderId.toString());
      final rawShopId = order?.shopId ??
          order?.restaurantId ??
          ActiveOrderState.instance.shopId;
      final sId = int.tryParse(rawShopId ?? '');
      if (sId != null && sId > 0) {
        final profile = await SearchRepository.instance.getShopProfileById(sId);
        if (profile != null && mounted) {
          final logo = profile.logoUrl ?? profile.primaryPhotoUrl;
          final resolved = FileUrlUtil.resolve(logo);
          setState(() {
            if (resolved.isNotEmpty && needsLogo) {
              _resolvedAvatarUrl = resolved;
            }
            if (needsName && profile.name.isNotEmpty) {
              _resolvedShopName = profile.name;
            }
          });
          InAppChatBanner.cacheShopInfo(
            widget.orderId,
            name: profile.name,
            logoUrl: resolved.isNotEmpty ? resolved : null,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _animateOut() async {
    if (!mounted) return;
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final displayShopName = _resolvedShopName ?? widget.senderName;

    return SafeArea(
      top: false,
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding > 0 ? topPadding + 6 : 14,
            left: 12,
            right: 12,
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: GestureDetector(
                  onTap: () {
                    widget.onTap();
                  },
                  onVerticalDragUpdate: (details) {
                    if (details.delta.dy < 0) {
                      setState(() {
                        _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(-120.0, 0.0);
                      });
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if (_dragOffsetY < -25 || (details.primaryVelocity ?? 0) < -150) {
                      _animateOut();
                    } else {
                      setState(() => _dragOffsetY = 0.0);
                    }
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                            blurRadius: 24,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top grab handle (affordance for swipe-up dismiss)
                          Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Real Shop Logo avatar with mini chat badge
                              _buildAvatar(),
                              const SizedBox(width: 12),
                              // Exactly two lines:
                              // Line 1: Big and Bold Shop Name
                              // Line 2: Small chat message text
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayShopName,
                                            style: AppFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Now',
                                          style: AppFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.messageText,
                                      style: AppFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF475569),
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Right chevron button
                              Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  PhosphorIcons.caretRightBold,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = _resolvedAvatarUrl ?? widget.avatarUrl;
    final resolvedUrl = FileUrlUtil.resolve(avatarUrl);
    final hasImage = resolvedUrl.isNotEmpty &&
        (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://'));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF8FAFC),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: resolvedUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildFallbackIcon(),
                    errorWidget: (_, __, ___) => _buildFallbackIcon(),
                  )
                : _buildFallbackIcon(),
          ),
        ),
        // Mini chat badge on bottom-right of avatar
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: Icon(
                PhosphorIcons.chatTeardropDotsFill,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient.scale(0.85),
      ),
      child: const Center(
        child: Icon(
          PhosphorIcons.storefrontFill,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}
