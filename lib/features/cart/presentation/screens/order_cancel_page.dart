import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../data/active_order_state.dart';
import '../../../../app.dart';
import '../../../../core/utils/file_url_util.dart';

class OrderCancelPage extends StatefulWidget {
  static bool isCurrentlyVisible = false;

  final String orderId;
  final String? reason;
  final String? shopId;
  final String? shopName;
  final String? shopNameMm;
  final String? shopNameTh;
  final String? shopLogo;
  final String? shopImageUrl;
  /// When true, shows the user-initiated cancellation copy instead of the
  /// "cancelled by the shop" message.
  final bool cancelledByUser;

  const OrderCancelPage({
    super.key,
    required this.orderId,
    this.reason,
    this.shopId,
    this.shopName,
    this.shopNameMm,
    this.shopNameTh,
    this.shopLogo,
    this.shopImageUrl,
    this.cancelledByUser = false,
  });

  @override
  State<OrderCancelPage> createState() => _OrderCancelPageState();
}

class _OrderCancelPageState extends State<OrderCancelPage> {
  @override
  void initState() {
    super.initState();
    OrderCancelPage.isCurrentlyVisible = true;
  }

  @override
  void dispose() {
    OrderCancelPage.isCurrentlyVisible = false;
    super.dispose();
  }

  String _getFullUrl(String? path) => FileUrlUtil.resolve(path);

  NavigatorState get _rootNavigator =>
      App.navigatorKey.currentState ?? Navigator.of(context);

  void _onViewRestaurant(BuildContext context) {
    ActiveOrderState.instance.clearOrder(orderId: widget.orderId);
    NavigationController.instance.goToFoodTab();

    if (widget.shopId != null && widget.shopId!.isNotEmpty) {
      _rootNavigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RestaurantDetailPage(
            id: widget.shopId!,
            name: widget.shopName,
            logoPath: _getFullUrl(widget.shopLogo),
            imagePath: _getFullUrl(widget.shopImageUrl),
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      _goHome(context);
    }
  }

  void _goHome(BuildContext context) {
    ActiveOrderState.instance.clearOrder(orderId: widget.orderId);
    NavigationController.instance.goToFoodTab();
    _rootNavigator.popUntil((route) => route.isFirst);
  }

  Widget _buildNoImagePlaceholder(BuildContext context, {bool isLogo = false}) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLogo ? PhosphorIcons.storefront : PhosphorIcons.imageBroken,
              color: Colors.grey[400],
              size: isLogo ? 24 : 32,
            ),
            if (!isLogo) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('common.no_image'),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = widget.shopLogo != null && widget.shopLogo!.isNotEmpty;
    final hasImage = widget.shopImageUrl != null && widget.shopImageUrl!.isNotEmpty;
    final localizedShopName = context.localized(
      en: widget.shopName,
      mm: widget.shopNameMm,
      th: widget.shopNameTh,
    );
    final hasShopInfo = localizedShopName.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.x, color: Colors.black),
          onPressed: () => _goHome(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Cancelled Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF1F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            PhosphorIconsFill.xCircle,
                            color: Color(0xFFE11D48),
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        widget.cancelledByUser
                            ? context.tr('order_cancel_user.title')
                            : context.tr('order_cancel.sorry'),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.cancelledByUser
                            ? context.tr('order_cancel_user.message')
                            : context.tr('order_cancel.message'),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 32),

                      // Shop Details Section
                      if (hasShopInfo || hasLogo || hasImage) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: ClipOval(
                                  child: (widget.shopLogo != null && widget.shopLogo!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: _getFullUrl(widget.shopLogo),
                                          fit: BoxFit.cover,
                                          errorWidget: (ctx, url, error) => const Icon(PhosphorIconsFill.storefront, color: Colors.grey),
                                        )
                                      : (widget.shopImageUrl != null && widget.shopImageUrl!.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: _getFullUrl(widget.shopImageUrl),
                                              fit: BoxFit.cover,
                                              errorWidget: (ctx, url, error) => const Icon(PhosphorIconsFill.storefront, color: Colors.grey),
                                            )
                                          : const Icon(PhosphorIconsFill.storefront, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Flexible(
                                child: Text(
                                  localizedShopName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      
                      // Reason Section — only when the shop cancelled the order.
                      if (!widget.cancelledByUser &&
                          widget.reason != null &&
                          widget.reason!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                PhosphorIconsFill.info,
                                color: Color(0xFFE11D48),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('order_cancel.reason_title'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF9F1239),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.reason!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFFBE123C),
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              
              // Back to Home Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0, top: 12),
                child: PrimaryGradientButton(
                  onPressed: () => _onViewRestaurant(context),
                  child: Text(
                    context.tr('order_cancel.view_restaurant'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

