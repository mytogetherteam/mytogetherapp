import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/active_order_state.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../reviews/data/repositories/order_review_repository.dart';
import '../../../reviews/data/repositories/shop_review_repository.dart';
import '../../../chat/presentation/screens/chat_page.dart';
import '../../../chat/presentation/widgets/floating_chat_head.dart';
import '../../../chat/data/models/chat_window.dart';
import '../../../chat/data/services/chat_service.dart';

class OrderCompletePage extends StatefulWidget {
  static bool isCurrentlyVisible = false;

  /// Replaces the current route with the order-complete screen.
  /// Prefer this over [navigateTo] when leaving order tracking to avoid
  /// lifecycle errors from removing routes while dependents are still mounted.
  static bool navigateReplacing(BuildContext context) {
    if (isCurrentlyVisible) return false;
    isCurrentlyVisible = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OrderCompletePage()),
    );
    return true;
  }

  /// Atomically checks the guard and pushes the page.
  /// Returns true if navigation was initiated, false if already visible.
  static bool navigateTo(BuildContext context) {
    if (isCurrentlyVisible) return false;
    isCurrentlyVisible = true; // Lock immediately (before async gap)
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OrderCompletePage()));
    return true;
  }

  /// Version for use with a NavigatorState (e.g. App.navigatorKey)
  static bool navigateWithState(NavigatorState? nav) {
    if (nav == null || isCurrentlyVisible) return false;
    isCurrentlyVisible = true; // Lock immediately
    nav.push(MaterialPageRoute(builder: (_) => const OrderCompletePage()));
    return true;
  }

  const OrderCompletePage({super.key});

  @override
  State<OrderCompletePage> createState() => _OrderCompletePageState();
}

class _OrderCompletePageState extends State<OrderCompletePage> {
  int _rating = 0;
  bool _isSubmitting = false;
  bool _orderFinalized = false;
  late final String? _orderId;
  DateTime? _chatClosesAt;
  bool _isChatWindowLoading = true;
  Timer? _chatWindowTicker;

  @override
  void initState() {
    super.initState();
    _orderId = ActiveOrderState.instance.orderId;
    OrderCompletePage.isCurrentlyVisible = true;
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_orderId != null) {
        ActiveOrderState.instance.setOrderStatus(4, orderId: _orderId);
      }
    });
    _loadChatWindow();
  }

  @override
  void dispose() {
    OrderCompletePage.isCurrentlyVisible = false;
    Future.microtask(() => FloatingChatHead.isHiddenNotifier.value = false);
    if (!_orderFinalized) {
      _finalizeOrder(silent: true);
    }
    _chatWindowTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadChatWindow() async {
    final orderId = int.tryParse(_orderId?.replaceAll('#', '') ?? '');
    if (orderId == null) {
      if (mounted) setState(() => _isChatWindowLoading = false);
      return;
    }

    final conversation = await ChatService.instance.getConversationByOrder(
      orderId,
    );
    if (!mounted) return;

    final order = ActiveOrderState.instance.getOrder(_orderId);
    final status =
        conversation?.orderStatus ?? order?.backendStatus ?? 'DELIVERED';
    // Just-completed screen: if no conversation yet (or older API payload
    // omitted updatedAt), start the 4h window from now.
    final completedAt = conversation?.orderUpdatedAt ?? DateTime.now();
    setState(() {
      _chatClosesAt = ChatWindow.closesAt(status, completedAt);
      _isChatWindowLoading = false;
    });
    _startChatWindowTicker();
  }

  void _startChatWindowTicker() {
    _chatWindowTicker?.cancel();
    if (_chatClosesAt == null) return;
    _chatWindowTicker = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) return;
      setState(() {});
      if (!_isChatWindowOpen) timer.cancel();
    });
  }

  bool get _isChatWindowOpen {
    final closesAt = _chatClosesAt;
    return closesAt == null || DateTime.now().isBefore(closesAt);
  }

  String get _chatTimeLeft => ChatWindow.compactTimeLeft(_chatClosesAt);

  void _finalizeOrder({bool silent = false}) {
    if (_orderFinalized) return;
    _orderFinalized = true;
    if (_orderId != null) {
      ActiveOrderState.instance.clearOrder(orderId: _orderId);
    } else {
      ActiveOrderState.instance.clearOrder();
    }
  }

  void _goToFoodTab() {
    _finalizeOrder();
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Submits the star rating to order-reviews (and mirrors to shop reviews),
  /// then clears the active order and returns home.
  Future<void> _onDone() async {
    if (_isSubmitting) return;

    final ratingValue = _rating;
    final orderIdStr = ActiveOrderState.instance.orderId;
    final orderId = int.tryParse(orderIdStr?.replaceAll('#', '') ?? '');
    final shopId = int.tryParse(ActiveOrderState.instance.shopId ?? '');

    if (ratingValue > 0 && orderId != null) {
      if (!await GuestAuthGuard.requireAccount(context)) return;
      setState(() => _isSubmitting = true);
      final result = await OrderReviewRepository.instance.create(
        orderId: orderId,
        rating: ratingValue.toDouble(),
      );
      if (result.success && shopId != null) {
        try {
          await ShopReviewRepository.instance.createOrUpdate(
            shopId: shopId,
            rating: ratingValue.toDouble(),
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final isBenign =
          result.success ||
          result.errorCode == OrderReviewErrorCode.alreadyReviewed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBenign
                ? context.tr('order_complete.rating_thanks')
                : (result.errorMessage ??
                      context.tr('order_complete.rating_failed')),
          ),
        ),
      );
    }

    if (!mounted) return;
    _goToFoodTab();
  }

  Future<void> _openChat() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;

    final order = ActiveOrderState.instance.getOrder(_orderId);
    final shopIdStr = order?.shopId ?? ActiveOrderState.instance.shopId;
    final shopId = int.tryParse(shopIdStr ?? '');
    final orderIdStr =
        order?.orderId.replaceAll('#', '') ??
        ActiveOrderState.instance.orderId?.replaceAll('#', '');
    final orderId = int.tryParse(orderIdStr ?? '');

    if (shopId == null || orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('chat.order_unavailable'))),
      );
      return;
    }

    if (mounted) {
      final peerName =
          order?.displayShopName ?? context.tr('common.restaurant');
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            orderId: orderId,
            peerName: peerName,
            peerSubtitle: context.tr('order_confirm.chat'),
            avatarUrl: order?.logoPath,
          ),
        ),
      );
    }
  }

  Widget _buildChatSupportCard() {
    final isOpen = _isChatWindowOpen;
    final timeLeft = _chatTimeLeft;
    final title = isOpen
        ? context.tr('chat.help_card_title')
        : context.tr('chat.closed_title');
    final body = isOpen
        ? context.tr('chat.help_card_body')
        : context.tr('chat.closed_body');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isOpen
            ? AppColors.primary.withValues(alpha: 0.06)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen
              ? AppColors.primary.withValues(alpha: 0.18)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOpen
                      ? PhosphorIcons.chatCircleTextFill
                      : Icons.lock_outline_rounded,
                  color: isOpen ? AppColors.primary : const Color(0xFF64748B),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openChat,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: isOpen
                    ? AppColors.primary
                    : const Color(0xFF475569),
                side: BorderSide(
                  color: isOpen ? AppColors.primary : const Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                isOpen
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.forum_outlined,
                size: 19,
              ),
              label: Text(
                isOpen
                    ? [
                        context.tr('chat.message_shop'),
                        if (!_isChatWindowLoading && timeLeft.isNotEmpty)
                          context.trArgs('chat.time_left', {'time': timeLeft}),
                      ].join(' · ')
                    : context.tr('chat.view_messages'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = ActiveOrderState.instance.getOrder(_orderId);
    final storeName = (order?.displayShopName ?? '').isNotEmpty
        ? order!.displayShopName
        : context.tr('common.restaurant');
    final arrivalTime = TimeFormatter.formatClock(DateTime.now());
    final logoPath = order?.logoPath;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToFoodTab();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () {
              _goToFoodTab();
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Header
              Center(
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: Center(
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                            child: const Icon(
                              PhosphorIconsBold.check,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('order_complete.title'),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.clock,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.trArgs('order_complete.arrived_at', {
                            'time': arrivalTime,
                          }),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Rating Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Logo with lazy-load and no-image fallback
                      ClipOval(
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: (logoPath != null && logoPath.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: logoPath,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CustomLoadingIndicator(size: 24),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      _buildNoImageAvatar(),
                                )
                              : _buildNoImageAvatar(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.trArgs('order_complete.rate_experience', {
                          'shop': storeName,
                        }),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('order_complete.rate_subtitle'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      // Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final isSelected = _rating > index;
                          return GestureDetector(
                            onTap: () async {
                              if (!await GuestAuthGuard.requireAccount(
                                context,
                              )) {
                                return;
                              }
                              if (!mounted) return;
                              setState(() => _rating = index + 1);
                              _onDone();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: isSelected ? 48 : 44,
                                  color: isSelected
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildChatSupportCard(),

              // Delivery proof photo (if the shop attached one on delivery)
              if (order?.proofPhotoUrl != null &&
                  order!.proofPhotoUrl!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildDeliveryProof(order.proofPhotoUrl!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoImageAvatar() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_not_supported_rounded,
        size: 36,
        color: Colors.grey,
      ),
    );
  }

  /// Shows the photo the shop attached when marking the order Delivered, as
  /// proof that the food was successfully delivered.
  Widget _buildDeliveryProof(String url) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.checkCircle,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('order_complete.delivery_proof'),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CustomLoadingIndicator(size: 24)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    size: 36,
                    color: Colors.grey,
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
