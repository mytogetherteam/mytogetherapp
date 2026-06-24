import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/active_order_state.dart';
import '../widgets/flexible_delivery_note.dart';
import '../../data/cart_manager.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';

import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/gradient_icon.dart';
import '../../../../core/auth/guest_auth_guard.dart';
import '../../../reviews/data/repositories/order_review_repository.dart';
import '../../../reviews/data/repositories/shop_review_repository.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderCompletePage()),
    );
    return true;
  }

  /// Version for use with a NavigatorState (e.g. App.navigatorKey)
  static bool navigateWithState(NavigatorState? nav) {
    if (nav == null || isCurrentlyVisible) return false;
    isCurrentlyVisible = true; // Lock immediately
    nav.push(
      MaterialPageRoute(builder: (_) => const OrderCompletePage()),
    );
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

  @override
  void initState() {
    super.initState();
    _orderId = ActiveOrderState.instance.orderId;
    OrderCompletePage.isCurrentlyVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_orderId != null) {
        ActiveOrderState.instance.setOrderStatus(4, orderId: _orderId);
      }
    });
  }

  @override
  void dispose() {
    OrderCompletePage.isCurrentlyVisible = false;
    if (!_orderFinalized) {
      _finalizeOrder(silent: true);
    }
    super.dispose();
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

      final isBenign = result.success ||
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

  @override
  Widget build(BuildContext context) {
    final order = ActiveOrderState.instance.getOrder(_orderId);
    final storeName = (order?.displayShopName ?? '').isNotEmpty
        ? order!.displayShopName
        : context.tr('common.restaurant');
    final deliveryFee = order?.deliveryFee ?? 0.0;
    final foodFromItems = (order?.orderItems ?? const <CartItem>[]).fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final foodPrice = order?.itemPrice ??
        order?.resolvedItemSubtotal ??
        (foodFromItems > 0 ? foodFromItems : 0);
    final taxAmount = order?.resolvedTaxAmount ?? 0;
    final total = order == null
        ? 0.0
        : (order.isFlexibleDelivery
            ? order.resolvedPayNowTotal(
                fallbackDeliveryFee: deliveryFee,
              )
            : (order.totalAmount ??
                order.resolvedGrandTotal(
                  fallbackDeliveryFee:
                      order.isPickupFulfillment ? 0 : deliveryFee,
                )));
    final displayTotal =
        order?.displayTotalAmount ?? total.toFormattedPrice();
    
    final arrivalTime = TimeFormatter.formatClock(DateTime.now());
    final logoPath = order?.logoPath;
    final orderItems = order?.orderItems ?? const <CartItem>[];

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('order_complete.title'),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.trArgs('order_complete.arrived_at', {'time': arrivalTime}),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            // Progress Bar (all filled)
            _buildProgressBar(),
            const SizedBox(height: 32),

            // Delivery proof photo (if the shop attached one on delivery)
            if (order?.proofPhotoUrl != null &&
                order!.proofPhotoUrl!.isNotEmpty) ...[
              _buildDeliveryProof(order.proofPhotoUrl!),
              const SizedBox(height: 24),
            ],

            // Rating Card
            Container(
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
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Column(
                      children: [
                        // Logo with lazy-load and no-image fallback
                        ClipOval(
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: (logoPath != null && logoPath.isNotEmpty)
                              ? Image.network(
                                  logoPath,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                    if (wasSynchronouslyLoaded || frame != null) return child;
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(child: CustomLoadingIndicator(size: 24)),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => _buildNoImageAvatar(),
                                )
                              : _buildNoImageAvatar(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.trArgs('order_complete.rate_experience', {'shop': storeName}),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('order_complete.rate_subtitle'),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
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
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 44,
                                  color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB), indent: 20, endIndent: 20),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        context.tr('cart.total'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTotal,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(PhosphorIcons.caretDown, size: 16, color: Colors.grey[600]),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryRow(
                                context.tr('payment.food_price'),
                                order?.displayFoodPrice ??
                                    foodPrice.toFormattedPrice(),
                              ),
                              if (order?.resolvedTaxEnable ?? true) ...[
                                const SizedBox(height: 12),
                                _buildSummaryRow(
                                  context.tr('order_status.tax'),
                                  order?.displayTaxAmount ??
                                      taxAmount.toFormattedPrice(),
                                ),
                              ],
                              if (!order!.isPickupFulfillment &&
                                  order.hasDeliveryFeeEstimate) ...[
                                const SizedBox(height: 12),
                                _buildDeliveryFeeRow(context, order, deliveryFee),
                              ],
                              if (order?.isFlexibleDelivery == true &&
                                  order?.isPickupFulfillment != true) ...[
                                const SizedBox(height: 12),
                                const FlexibleDeliveryNote(),
                              ],
                              if (orderItems.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                    height: 1,
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                ...orderItems.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item.quantity}x ${item.title}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item.total.toFormattedPrice(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ] else
                                Text(
                                  context.tr('order_complete.items_placeholder'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // "Done" button: submit rating (if any), clear order, go home
            PrimaryGradientButton(
              onPressed: _isSubmitting ? null : _onDone,
              child: _isSubmitting
                  ? const CustomLoadingIndicator(size: 22, color: Colors.white)
                  : Text(
                      context.tr('order_complete.done'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryFeeRow(
    BuildContext context,
    ActiveOrderItem? order,
    double deliveryFee,
  ) {
    final isFlexible = order?.isFlexibleDelivery == true;
    final isConfirmed = deliveryFee > 0;
    final feeLabel = isFlexible || !isConfirmed
        ? context.tr('payment.est_delivery_fee')
        : context.tr('order_status.delivery_fee');
    final badgeLabel = isFlexible || !isConfirmed
        ? context.tr('payment.delivery_fee_badge_estimate')
        : context.tr('payment.delivery_fee_badge_confirmed');
    final feeAmount = order?.displayDeliveryFee?.isNotEmpty == true
        ? order!.displayDeliveryFee!
        : (isConfirmed ? deliveryFee.toFormattedPrice() : '+฿ 0');

    return Row(
      children: [
        const GradientIcon(icon: PhosphorIconsFill.moped, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            feeLabel,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badgeLabel,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFEF4444),
            ),
          ),
        ),
        const Spacer(),
        GradientText(
          feeAmount,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNoImageAvatar() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported_rounded, size: 36, color: Colors.grey),
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
                Icon(PhosphorIcons.checkCircle, size: 18, color: AppColors.primary),
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
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CustomLoadingIndicator(size: 24)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
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

  Widget _buildProgressBar() {
    return Row(
      children: [
        _buildStepNode(PhosphorIcons.wallet),
        _buildStepLine(),
        _buildStepNode(PhosphorIcons.cookingPot),
        _buildStepLine(),
        _buildStepNode(PhosphorIcons.moped),
        _buildStepLine(),
        _buildStepNode(PhosphorIcons.house),
      ],
    );
  }

  Widget _buildStepNode(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 3,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
      ),
    );
  }
}
