import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/active_order_state.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';

import '../../../../core/utils/price_formatter.dart';
import '../../../reviews/data/repositories/order_review_repository.dart';

class OrderCompletePage extends StatefulWidget {
  static bool isCurrentlyVisible = false;

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

  @override
  void initState() {
    super.initState();
    // isCurrentlyVisible is already set to true by navigateTo() before push.
    // Set it here as a fallback for any direct constructor usage.
    OrderCompletePage.isCurrentlyVisible = true;
    // We don't clear the order here anymore so it remains in the tracking card
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActiveOrderState.instance.setOrderStatus(4); // 4 = Completed
    });
  }

  @override
  void dispose() {
    OrderCompletePage.isCurrentlyVisible = false;
    super.dispose();
  }

  void _goToFoodTab() {
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Submits the star rating (if one was picked) to the order-reviews API,
  /// then clears the active order and returns home. The order id is captured
  /// before clearing because clearOrder() wipes ActiveOrderState.
  Future<void> _onDone() async {
    if (_isSubmitting) return;

    final ratingValue = _rating;
    final orderIdStr = ActiveOrderState.instance.orderId;
    final orderId = int.tryParse(orderIdStr?.replaceAll('#', '') ?? '');

    if (ratingValue > 0 && orderId != null) {
      setState(() => _isSubmitting = true);
      final result = await OrderReviewRepository.instance.create(
        orderId: orderId,
        rating: ratingValue.toDouble(),
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // alreadyReviewed is a benign outcome here — don't block the user.
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
    ActiveOrderState.instance.clearOrder();
    _goToFoodTab();
  }

  @override
  Widget build(BuildContext context) {
    final state = ActiveOrderState.instance;
    final storeName = state.displayShopName.isNotEmpty
        ? state.displayShopName
        : context.tr('common.restaurant');
    final total = state.totalAmount ?? 0.0;
    
    // In a real app we'd format actual Arrival time, mocked for now
    final now = DateTime.now();
    final arrivalTime = '${now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final logoPath = state.logoPath;

    return Scaffold(
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
            if (state.proofPhotoUrl != null &&
                state.proofPhotoUrl!.isNotEmpty) ...[
              _buildDeliveryProof(state.proofPhotoUrl!),
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
                              onTap: () => setState(() => _rating = index + 1),
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
                            total.toFormattedPrice(),
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
                            children: state.orderItems.isEmpty 
                                ? [
                                    Text(context.tr('order_complete.items_placeholder'), 
                                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                                    )
                                  ]
                                : state.orderItems.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  )).toList(),
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
