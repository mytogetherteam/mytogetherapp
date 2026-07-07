import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/cart/data/active_order_state.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_unread_controller.dart';
import 'package:mytogetherapp/features/chat/presentation/screens/chat_page.dart';
import 'package:mytogetherapp/features/chat/presentation/widgets/chat_unread_badge.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/app.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/utils/file_url_util.dart';

class FloatingChatHead extends StatefulWidget {
  /// When true the chat head is hidden (e.g. inside ChatPage).
  static final ValueNotifier<bool> isHiddenNotifier = ValueNotifier(false);

  /// Persist position across hide/show cycles so it doesn't reset.
  static Offset _position = const Offset(0, 200);

  const FloatingChatHead({super.key});

  @override
  State<FloatingChatHead> createState() => _FloatingChatHeadState();
}

class _FloatingChatHeadState extends State<FloatingChatHead> {
  Timer? _fadeTimer;
  bool _isFaded = false;

  @override
  void initState() {
    super.initState();
    ChatUnreadController.instance.start();
    ActiveOrderState.instance.addListener(_onActiveOrderChanged);
    _resetFadeTimer();

    // Set initial position to right edge on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (FloatingChatHead._position.dx == 0) {
          setState(() {
            FloatingChatHead._position = Offset(screenWidth - 60, kToolbarHeight + 100);
          });
        }
      }
    });
  }

  void _resetFadeTimer() {
    _fadeTimer?.cancel();
    if (_isFaded && mounted) {
      setState(() => _isFaded = false);
    }
    _fadeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isFaded = true);
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    ActiveOrderState.instance.removeListener(_onActiveOrderChanged);
    super.dispose();
  }

  void _onActiveOrderChanged() {
    if (mounted) setState(() {});
  }

  int? get _currentOrderId {
    final idStr = ActiveOrderState.instance.orderId?.replaceAll('#', '');
    return idStr != null ? int.tryParse(idStr) : null;
  }

  void _openChat() {
    final orderId = _currentOrderId;
    if (orderId == null) return;
    final order = ActiveOrderState.instance.getOrder(ActiveOrderState.instance.orderId);
    final shopName = (order?.shopName?.isNotEmpty == true)
        ? order!.shopName!
        : (order?.restaurantName ?? 'Restaurant');
    final logoPath = order?.logoPath;

    App.navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (context) => ChatPage(
        orderId: orderId,
        peerName: shopName,
        peerSubtitle: context.tr('common.restaurant'),
        avatarUrl: logoPath,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _currentOrderId;
    final order = ActiveOrderState.instance.getOrder(ActiveOrderState.instance.orderId);
    if (orderId == null || order == null || order.orderStatus < 1) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeX = FloatingChatHead._position.dx.clamp(0.0, screenWidth - 60);
    final safeY = FloatingChatHead._position.dy.clamp(kToolbarHeight, screenHeight - 80);

    final shopName = (order.shopName?.isNotEmpty == true)
        ? order.shopName!
        : (order.restaurantName ?? 'Restaurant');
    final logoPath = order.logoPath;

    // SizedBox.expand + inner Stack so Positioned works correctly
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: safeX,
            top: safeY,
            child: Column(
              crossAxisAlignment: safeX < screenWidth / 2
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Draggable chat head circle
                Listener(
                  onPointerDown: (_) => _resetFadeTimer(),
                  child: AnimatedOpacity(
                    opacity: _isFaded ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        _resetFadeTimer();
                    setState(() {
                      FloatingChatHead._position = Offset(
                        (FloatingChatHead._position.dx + details.delta.dx)
                            .clamp(0.0, screenWidth - 60),
                        (FloatingChatHead._position.dy + details.delta.dy)
                            .clamp(kToolbarHeight, screenHeight - 80),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    final targetX = (FloatingChatHead._position.dx < screenWidth / 2)
                        ? 0.0
                        : (screenWidth - 60.0);
                    setState(() {
                      FloatingChatHead._position =
                          Offset(targetX, FloatingChatHead._position.dy);
                    });
                  },
                  onTap: _openChat,
                  child: Material(
                    color: Colors.transparent,
                    child: ChatUnreadBadge(
                      orderId: orderId,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Main circle with shop logo
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (logoPath != null && logoPath.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: FileUrlUtil.resolve(logoPath),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => const Icon(
                                          PhosphorIconsFill.storefront,
                                          color: Colors.grey,
                                          size: 28),
                                    )
                                  : const Icon(PhosphorIconsFill.storefront,
                                      color: Colors.grey, size: 28),
                            ),
                          ),
                          // Small chat icon badge
                          Positioned(
                            bottom: -2,
                            left: -2,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Center(
                                child: Icon(
                                  PhosphorIconsFill.chatCircleText,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
  }
}
