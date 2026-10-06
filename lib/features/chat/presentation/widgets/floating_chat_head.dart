import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/app.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/utils/file_url_util.dart';
import 'package:mytogetherapp/features/cart/data/active_order_state.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_unread_controller.dart';
import 'package:mytogetherapp/features/chat/presentation/screens/chat_page.dart';
import 'package:mytogetherapp/features/chat/presentation/widgets/chat_unread_badge.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class FloatingChatHead extends StatefulWidget {
  /// When true the chat head is hidden (e.g. inside ChatPage).
  static final ValueNotifier<bool> isHiddenNotifier = ValueNotifier(false);

  /// Persist position across hide/show cycles so it doesn't reset.
  static Offset _position = const Offset(0, 200);

  /// Last edge the head snapped to (`true` = left). Used after dismiss re-show.
  static bool _dockLeft = false;

  /// Orders whose floating head the user dismissed (Messenger-style close).
  static final Set<int> _dismissedOrderIds = <int>{};

  static const double headSize = 56;
  static const double closeZoneSize = 64;
  static const double closeHitRadius = 72;

  const FloatingChatHead({super.key});

  @override
  State<FloatingChatHead> createState() => _FloatingChatHeadState();
}

class _FloatingChatHeadState extends State<FloatingChatHead>
    with TickerProviderStateMixin {
  Timer? _fadeTimer;
  bool _isFaded = false;
  bool _isDragging = false;
  bool _overCloseZone = false;
  bool _isDismissing = false;
  double _headScale = 1.0;

  late final AnimationController _dismissController;
  late final AnimationController _closeZoneController;
  late final Listenable _closeUiListenable;
  ValueNotifier<int>? _unreadNotifier;
  int? _listeningOrderId;

  @override
  void initState() {
    super.initState();
    ChatUnreadController.instance.start();
    ActiveOrderState.instance.addListener(_onActiveOrderChanged);

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _closeZoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _closeUiListenable = Listenable.merge([
      _closeZoneController,
      _dismissController,
    ]);

    _resetFadeTimer();
    _bindUnreadListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screenWidth = MediaQuery.of(context).size.width;
      if (FloatingChatHead._position.dx == 0) {
        setState(() {
          FloatingChatHead._dockLeft = false;
          FloatingChatHead._position = Offset(
            screenWidth - FloatingChatHead.headSize - 8,
            kToolbarHeight + 100,
          );
        });
      }
    });
  }

  void _bindUnreadListener() {
    final orderId = _currentOrderId;
    if (orderId == _listeningOrderId) return;

    _unreadNotifier?.removeListener(_onUnreadChanged);
    _listeningOrderId = orderId;
    if (orderId == null) {
      _unreadNotifier = null;
      return;
    }

    _unreadNotifier = ChatUnreadController.instance.notifierFor(orderId);
    _unreadNotifier!.addListener(_onUnreadChanged);
  }

  void _onUnreadChanged() {
    final orderId = _currentOrderId;
    final unread = _unreadNotifier?.value ?? 0;
    // Re-show after dismiss when the shop sends a new message.
    if (orderId != null &&
        unread > 0 &&
        FloatingChatHead._dismissedOrderIds.remove(orderId)) {
      if (mounted) {
        setState(() {
          _isFaded = false;
          _headScale = 1.0;
        });
        _resetFadeTimer();
      }
    }
  }

  void _resetFadeTimer() {
    _fadeTimer?.cancel();
    if (_isFaded && mounted) {
      setState(() => _isFaded = false);
    }
    if (_isDragging || _isDismissing) return;
    _fadeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDragging && !_isDismissing) {
        setState(() => _isFaded = true);
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _unreadNotifier?.removeListener(_onUnreadChanged);
    ActiveOrderState.instance.removeListener(_onActiveOrderChanged);
    _dismissController.dispose();
    _closeZoneController.dispose();
    super.dispose();
  }

  void _onActiveOrderChanged() {
    _bindUnreadListener();
    if (mounted) setState(() {});
  }

  int? get _currentOrderId {
    final idStr = ActiveOrderState.instance.orderId?.replaceAll('#', '');
    return idStr != null ? int.tryParse(idStr) : null;
  }

  Offset _clampPosition(Offset pos, Size screen) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Offset(
      pos.dx.clamp(8.0, screen.width - FloatingChatHead.headSize - 8),
      pos.dy.clamp(
        MediaQuery.of(context).padding.top + 8,
        screen.height - FloatingChatHead.headSize - bottomPad - 24,
      ),
    );
  }

  Offset _closeZoneCenter(Size screen) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Offset(
      screen.width / 2,
      screen.height - bottomPad - 56 - FloatingChatHead.closeZoneSize / 2,
    );
  }

  Offset _headCenter(Offset topLeft) {
    final half = FloatingChatHead.headSize / 2;
    return Offset(topLeft.dx + half, topLeft.dy + half);
  }

  bool _isNearCloseZone(Offset headTopLeft, Size screen) {
    final distance =
        (_headCenter(headTopLeft) - _closeZoneCenter(screen)).distance;
    return distance <= FloatingChatHead.closeHitRadius;
  }

  void _openChat() {
    if (_isDragging || _isDismissing) return;
    final orderId = _currentOrderId;
    if (orderId == null) return;
    final order =
        ActiveOrderState.instance.getOrder(ActiveOrderState.instance.orderId);
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

  Future<void> _dismissHead(Size screen) async {
    if (_isDismissing) return;
    final orderId = _currentOrderId;
    if (orderId == null) return;

    // Remember which edge to restore when the head comes back.
    final restoreX = FloatingChatHead._dockLeft
        ? 8.0
        : screen.width - FloatingChatHead.headSize - 8;
    // Keep a comfortable mid-screen Y, not the close-zone Y.
    final restoreY = (FloatingChatHead._position.dy)
        .clamp(
          MediaQuery.of(context).padding.top + 80,
          screen.height * 0.55,
        )
        .toDouble();

    setState(() {
      _isDismissing = true;
      _isDragging = false;
      // Keep close-zone "armed" look while flying in (_isDismissing covers color).
      _overCloseZone = true;
    });
    HapticFeedback.mediumImpact();

    final target = _closeZoneCenter(screen) -
        const Offset(
          FloatingChatHead.headSize / 2,
          FloatingChatHead.headSize / 2,
        );
    setState(() => FloatingChatHead._position = target);

    await _dismissController.forward(from: 0);
    if (!mounted) return;

    FloatingChatHead._dismissedOrderIds.add(orderId);
    // Park on the edge so a later re-show (new unread) isn't stuck at bottom-center.
    FloatingChatHead._position = _clampPosition(
      Offset(restoreX, restoreY),
      screen,
    );
    await _closeZoneController.reverse();
    if (!mounted) return;

    setState(() {
      _isDismissing = false;
      _overCloseZone = false;
      _headScale = 1.0;
      _dismissController.value = 0;
    });
    _resetFadeTimer();
  }

  void _snapToEdge(Size screen) {
    final midX = FloatingChatHead._position.dx + FloatingChatHead.headSize / 2;
    final dockLeft = midX < screen.width / 2;
    final targetX = dockLeft
        ? 8.0
        : screen.width - FloatingChatHead.headSize - 8;
    FloatingChatHead._dockLeft = dockLeft;
    setState(() {
      FloatingChatHead._position = _clampPosition(
        Offset(targetX, FloatingChatHead._position.dy),
        screen,
      );
      _isDragging = false;
      _overCloseZone = false;
      _headScale = 1.0;
    });
    _closeZoneController.reverse();
    _resetFadeTimer();
  }

  void _cancelDrag(Size screen) {
    if (_isDismissing) return;
    if (!_isDragging && _closeZoneController.value == 0) return;
    _snapToEdge(screen);
  }

  void _onPanStart(DragStartDetails _) {
    if (_isDismissing) return;
    _fadeTimer?.cancel();
    setState(() {
      _isDragging = true;
      _isFaded = false;
      _headScale = 1.08;
    });
    _closeZoneController.forward();
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details, Size screen) {
    if (_isDismissing) return;
    var next = FloatingChatHead._position + details.delta;
    final near = _isNearCloseZone(next, screen);

    // Soft magnetic pull into the close zone (Messenger-like).
    if (near) {
      final target = _closeZoneCenter(screen) -
          const Offset(
            FloatingChatHead.headSize / 2,
            FloatingChatHead.headSize / 2,
          );
      next = Offset.lerp(next, target, 0.22)!;
    }

    next = _clampPosition(next, screen);
    final stillNear = _isNearCloseZone(next, screen);

    if (stillNear != _overCloseZone) {
      if (stillNear) HapticFeedback.lightImpact();
      setState(() {
        FloatingChatHead._position = next;
        _overCloseZone = stillNear;
        _headScale = stillNear ? 0.82 : 1.08;
      });
    } else {
      setState(() => FloatingChatHead._position = next);
    }
  }

  void _onPanEnd(DragEndDetails _, Size screen) {
    if (_isDismissing) return;
    if (_overCloseZone) {
      unawaited(_dismissHead(screen));
      return;
    }
    _snapToEdge(screen);
  }

  void _onPanCancel() {
    if (!mounted) return;
    final screen = MediaQuery.of(context).size;
    _cancelDrag(screen);
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _currentOrderId;
    final order =
        ActiveOrderState.instance.getOrder(ActiveOrderState.instance.orderId);
    if (orderId == null ||
        order == null ||
        order.orderStatus < 1 ||
        FloatingChatHead._dismissedOrderIds.contains(orderId)) {
      return const SizedBox.shrink();
    }

    final screen = MediaQuery.of(context).size;
    final safePos = _clampPosition(FloatingChatHead._position, screen);
    final logoPath = order.logoPath;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft scrim + close zone (Messenger-style)
          AnimatedBuilder(
            animation: _closeUiListenable,
            builder: (context, _) {
              final t = Curves.easeOutCubic
                  .transform(_closeZoneController.value);
              if (t <= 0.001) return const SizedBox.shrink();

              final zoneCenter = _closeZoneCenter(screen);
              final zoneScale = _overCloseZone || _isDismissing ? 1.18 : 1.0;
              final zoneColor = _overCloseZone || _isDismissing
                  ? const Color(0xFFE53935)
                  : Colors.white.withValues(alpha: 0.92);

              return IgnorePointer(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.18 * t),
                      ),
                    ),
                    Positioned(
                      left: zoneCenter.dx - FloatingChatHead.closeZoneSize / 2,
                      top: zoneCenter.dy - FloatingChatHead.closeZoneSize / 2,
                      child: Transform.scale(
                        scale: zoneScale * (0.85 + 0.15 * t),
                        child: Opacity(
                          opacity: t,
                          child: Container(
                            width: FloatingChatHead.closeZoneSize,
                            height: FloatingChatHead.closeZoneSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: zoneColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: _overCloseZone || _isDismissing
                                    ? Colors.white
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 30,
                              color: _overCloseZone || _isDismissing
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          AnimatedPositioned(
            duration: _isDragging
                ? Duration.zero
                : _isDismissing
                    ? const Duration(milliseconds: 200)
                    : const Duration(milliseconds: 320),
            curve: _isDismissing ? Curves.easeInCubic : Curves.easeOutCubic,
            left: safePos.dx,
            top: safePos.dy,
            child: AnimatedBuilder(
              animation: _dismissController,
              builder: (context, child) {
                final dismissT =
                    Curves.easeIn.transform(_dismissController.value);
                final opacity = _isDismissing
                    ? (1.0 - dismissT)
                    : (_isFaded ? 0.45 : 1.0);
                final scale =
                    _isDismissing ? (1.0 - dismissT) * 0.55 : _headScale;

                return AnimatedOpacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  duration: _isDismissing
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  child: AnimatedScale(
                    scale: scale,
                    duration: _isDismissing
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    child: child,
                  ),
                );
              },
              child: IgnorePointer(
                // Opacity 0 still hit-tests; block input while flying into X.
                ignoring: _isDismissing,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onPanStart,
                  onPanUpdate: (d) => _onPanUpdate(d, screen),
                  onPanEnd: (d) => _onPanEnd(d, screen),
                  onPanCancel: _onPanCancel,
                  onTap: _openChat,
                  child: Material(
                    color: Colors.transparent,
                    child: ChatUnreadBadge(
                      orderId: orderId,
                      child: _ChatHeadVisual(logoPath: logoPath),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatHeadVisual extends StatelessWidget {
  final String? logoPath;

  const _ChatHeadVisual({this.logoPath});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: FloatingChatHead.headSize,
          height: FloatingChatHead.headSize,
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
            child: (logoPath != null && logoPath!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: FileUrlUtil.resolve(logoPath!),
                    width: FloatingChatHead.headSize,
                    height: FloatingChatHead.headSize,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const Icon(
                      PhosphorIconsFill.storefront,
                      color: Colors.grey,
                      size: 28,
                    ),
                  )
                : const Icon(
                    PhosphorIconsFill.storefront,
                    color: Colors.grey,
                    size: 28,
                  ),
          ),
        ),
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
    );
  }
}
