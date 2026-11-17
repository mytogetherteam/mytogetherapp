import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/active_order_state.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../reviews/data/repositories/order_review_repository.dart';
import '../../../reviews/data/repositories/shop_review_repository.dart';
import '../../../chat/presentation/screens/chat_page.dart';
import '../../../chat/presentation/widgets/chat_window_hint.dart';
import '../../../chat/data/models/chat_window.dart';
import '../../../chat/data/services/chat_service.dart';
import '../../../home/presentation/widgets/my_together_verified_badge.dart';

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
    isCurrentlyVisible = true;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderCompletePage()),
    );
    return true;
  }

  /// Version for use with a NavigatorState (e.g. App.navigatorKey)
  static bool navigateWithState(NavigatorState? nav) {
    if (nav == null || isCurrentlyVisible) return false;
    isCurrentlyVisible = true;
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
  bool _hasSubmittedRating = false;
  bool _orderFinalized = false;
  late final String? _orderId;
  ActiveOrderItem? _orderSnapshot;
  DateTime? _chatClosesAt;
  bool _isChatWindowLoading = true;
  Timer? _chatWindowTicker;
  bool _isReceiptExpanded = false;

  @override
  void initState() {
    super.initState();
    _orderId = ActiveOrderState.instance.orderId;
    _orderSnapshot = ActiveOrderState.instance.getOrder(_orderId);
    OrderCompletePage.isCurrentlyVisible = true;
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

    final order = _orderSnapshot ?? ActiveOrderState.instance.getOrder(_orderId);
    final status =
        conversation?.orderStatus ?? order?.backendStatus ?? 'DELIVERED';
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
    // If user rated but hasn't tapped submit, silently submit before leaving
    if (_rating > 0 && !_hasSubmittedRating && !_isSubmitting) {
      _submitRating(silent: true);
    }
    _finalizeOrder();
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Submits the star rating to order-reviews (and mirrors to shop reviews).
  Future<void> _submitRating({bool silent = false}) async {
    if (_isSubmitting || _hasSubmittedRating || _rating == 0) return;

    final ratingValue = _rating;
    final orderIdStr = _orderSnapshot?.orderId ?? ActiveOrderState.instance.orderId;
    final orderId = int.tryParse(orderIdStr?.replaceAll('#', '') ?? '');
    final shopId = int.tryParse(_orderSnapshot?.shopId ?? ActiveOrderState.instance.shopId ?? '');

    if (orderId == null) {
      if (!silent) _goToFoodTab();
      return;
    }

    if (!silent && !await GuestAuthGuard.requireAccount(context)) return;

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
      } catch (e) {
        if (kDebugMode) debugPrint('order_complete_page.dart: ignored error: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _hasSubmittedRating = true;
    });

    HapticFeedback.mediumImpact();

    if (!silent) {
      final isBenign =
          result.success ||
          result.errorCode == OrderReviewErrorCode.alreadyReviewed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF0F172A),
          content: Text(
            isBenign
                ? context.tr('order_complete.rating_thanks')
                : (result.errorMessage ??
                      context.tr('order_complete.rating_failed')),
            style: AppFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
  }

  Future<void> _openChat() async {
    if (!await GuestAuthGuard.requireAccount(context)) return;
    if (!mounted) return;

    final order = _orderSnapshot ?? ActiveOrderState.instance.getOrder(_orderId);
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

  String _getRatingFeedback(int rating) {
    switch (rating) {
      case 1:
        return 'မကောင်းပါ 😞';
      case 2:
        return 'သင့်တင့်ပါသည် 😐';
      case 3:
        return 'ကောင်းပါသည် 🙂';
      case 4:
        return 'အလွန်ကောင်းပါသည် 😊';
      case 5:
        return 'အရမ်းကောင်းပါတယ်! 😍';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _orderSnapshot ?? ActiveOrderState.instance.getOrder(_orderId);
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
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Clean Top Header Bar
              _buildTopBar(context),

              // 2. Scrollable Body Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Celebratory Success Header
                      _buildSuccessHero(context, arrivalTime),
                      const SizedBox(height: 24),

                      // Card 1: Restaurant Rating Experience
                      _buildRatingCard(context, order, storeName, logoPath),
                      const SizedBox(height: 16),

                      // Card 2: Order Snapshot / Receipt (if items present)
                      if (order != null && (order.orderItems.isNotEmpty || (order.totalAmount != null && order.totalAmount! > 0))) ...[
                        _buildOrderReceiptCard(context, order),
                        const SizedBox(height: 16),
                      ],

                      // Card 3: Customer Care & Chat Support Card
                      _buildChatSupportCard(),

                      // Card 4: Delivery Proof Photo (if present)
                      if (order?.proofPhotoUrl != null &&
                          order!.proofPhotoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDeliveryProof(order.proofPhotoUrl!),
                      ],

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Sticky Action Bar
              _buildBottomActionBar(context),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. Top Header Bar (Circle Close + Clean Title + Home Icon)
  // -------------------------------------------------------------
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Close Button (Matches OrderCancelPage / OrderStatusPage)
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _goToFoodTab();
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),

          // Title Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'Order Completed',
                  style: AppFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // Right Spacer (Balances the 40px Close button to keep title centered)
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. Celebratory Hero Banner (Dual Pulse Ring + Typography)
  // -------------------------------------------------------------
  Widget _buildSuccessHero(BuildContext context, String arrivalTime) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Dual Glow Success Badge
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33FF4757),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsBold.check,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Main Title
        Text(
          'အော်ဒါ ပို့ဆောင်ပြီးပါပြီ!',
          style: AppFonts.poppins(
            fontSize: 22.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Arrival Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.clock,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'ရောက်ရှိချိန်: $arrivalTime',
                style: AppFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 3. Shop & Delightful Interactive Rating Card
  // -------------------------------------------------------------
  Widget _buildRatingCard(
    BuildContext context,
    ActiveOrderItem? order,
    String storeName,
    String? logoPath,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Column(
        children: [
          // Shop Avatar with clean frame
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: (logoPath != null && logoPath.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: logoPath,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: CustomLoadingIndicator(size: 22),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildNoImageAvatar(),
                    )
                  : _buildNoImageAvatar(),
            ),
          ),
          const SizedBox(height: 14),

          // Restaurant Name with Verified Badge
          VerifiedRestaurantNameRow(
            name: storeName,
            isVerified: order?.isVerified ?? false,
            style: AppFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
            centered: true,
            badgeSize: MyTogetherVerifiedBadge.detailSize,
          ),
          const SizedBox(height: 6),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              context.tr('order_complete.rate_subtitle'),
              style: AppFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // 5-Star Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isSelected = _rating >= starIndex;
              return GestureDetector(
                onTap: _hasSubmittedRating
                    ? null
                    : () async {
                        HapticFeedback.lightImpact();
                        setState(() => _rating = starIndex);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        if (isSelected) {
                          return const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds);
                        }
                        return const LinearGradient(
                          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                        ).createShader(bounds);
                      },
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Dynamic Feeling / Reaction Pill
          if (_rating > 0) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                _getRatingFeedback(_rating),
                style: AppFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB45309),
                ),
              ),
            ),
          ],

          // Submit Rating Button or Success Message
          if (_rating > 0 && !_hasSubmittedRating) ...[
            const SizedBox(height: 18),
            PrimaryGradientButton(
              height: 44,
              isLoading: _isSubmitting,
              onPressed: () => _submitRating(),
              borderRadius: BorderRadius.circular(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(PhosphorIconsBold.star, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'အဆင့်သတ်မှတ်ချက် ပေးပို့မည်',
                    style: AppFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_hasSubmittedRating) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    PhosphorIconsFill.checkCircle,
                    color: Color(0xFF16A34A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'အဆင့်သတ်မှတ်ချက် ပေးပို့ပြီးပါပြီ။ ကျေးဇူးတင်ပါသည်!',
                    style: AppFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. Order Snapshot / Receipt Card
  // -------------------------------------------------------------
  Widget _buildOrderReceiptCard(BuildContext context, ActiveOrderItem order) {
    final orderNo = order.lastOrderNo ?? (order.orderId.length > 8 ? order.orderId.substring(0, 8) : order.orderId);
    final totalText = order.displayTotalAmount ??
        (order.totalAmount != null ? '${order.totalAmount!.toStringAsFixed(0)} ฿' : '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            onTap: () {
              setState(() => _isReceiptExpanded = !_isReceiptExpanded);
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      PhosphorIconsBold.receipt,
                      size: 19,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'အော်ဒါ အကျဉ်းချုပ်',
                        style: AppFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (totalText.isNotEmpty)
                            Text(
                              'စုစုပေါင်း: $totalText',
                              style: AppFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          if (orderNo.isNotEmpty) ...[
                            if (totalText.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                '#$orderNo',
                                style: AppFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isReceiptExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF64748B),
                  size: 22,
                ),
              ],
            ),
          ),

          // Expanded Items List
          if (_isReceiptExpanded && order.orderItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            ...order.orderItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'x${item.quantity}',
                        style: AppFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.total.toStringAsFixed(0)} ฿',
                      style: AppFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Delivery Address (if available)
          if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsBold.mapPin,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.deliveryAddress!,
                      style: AppFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 5. Customer Care & Chat Support Card (Refined Grab/Bolt Style)
  // -------------------------------------------------------------
  Widget _buildChatSupportCard() {
    final isOpen = _isChatWindowOpen;
    final title = isOpen
        ? context.tr('chat.help_card_title')
        : context.tr('chat.closed_title');
    final body = isOpen
        ? context.tr('chat.help_card_body')
        : context.tr('chat.closed_body');

    final timeLeft = ChatWindow.timeLeftUntil(_chatClosesAt);
    final timeStr = timeLeft != null ? context.countdown(timeLeft) : null;

    return Container(
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.white
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen
              ? const Color(0xFFF1F5F9)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _openChat();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Chat Icon Badge + Title (Single Line) + Subtitle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: isOpen ? AppColors.primaryGradient : null,
                        color: isOpen ? null : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isOpen
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          isOpen
                              ? PhosphorIconsFill.chatCircleText
                              : Icons.lock_outline_rounded,
                          color: isOpen ? Colors.white : const Color(0xFF64748B),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppFonts.poppins(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            body,
                            style: AppFonts.poppins(
                              fontSize: 12.5,
                              height: 1.4,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bottom: Clean Action Banner (Countdown Left + Action Link Right)
                if (isOpen && !_isChatWindowLoading) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            timeStr != null
                                ? '$timeStr ကျန်'
                                : '၄ နာရီအတွင်း စာပို့နိုင်ပါသည်',
                            style: AppFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('chat.message_shop'),
                              style: AppFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (!isOpen) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.tr('chat.closed_title'),
                            style: AppFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('chat.view_messages'),
                              style: AppFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Color(0xFF475569),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 6. Delivery Proof Photo Card
  // -------------------------------------------------------------
  Widget _buildDeliveryProof(String url) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                  style: AppFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to view',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showProofPhotoDialog(url),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
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
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Zoom Photo',
                          style: AppFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProofPhotoDialog(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CustomLoadingIndicator(size: 32),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        size: 48,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 7. Sticky Bottom Action Bar (Back to Home)
  // -------------------------------------------------------------
  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: PrimaryGradientButton(
        height: 52,
        borderRadius: BorderRadius.circular(16),
        onPressed: () {
          HapticFeedback.lightImpact();
          _goToFoodTab();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsBold.house,
              color: Colors.white,
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              'ပင်မစာမျက်နှာသို့ ပြန်သွားမည်',
              style: AppFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImageAvatar() {
    return Container(
      width: 76,
      height: 76,
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 32,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
