import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../data/active_order_state.dart';
import '../../../../core/theme/app_colors.dart';
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
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                        ),
                        child: Icon(
                          PhosphorIcons.xCircleFill,
                          color: const Color(0xFFEF4444),
                          size: 50,
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
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[100]!),
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
                              // Cover/Logo Section (Large Banner Style)
                              Container(
                                width: double.infinity,
                                height: 160,
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.grey[50],
                                  border: Border.all(color: Colors.grey[100]!, width: 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: (widget.shopImageUrl != null && widget.shopImageUrl!.isNotEmpty)
                                      ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                          imageUrl: _getFullUrl(widget.shopImageUrl),
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          errorWidget: (ctx, url, error) => _buildNoImagePlaceholder(ctx),
                                        )
                                      : (widget.shopLogo != null && widget.shopLogo!.isNotEmpty)
                                          ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                              imageUrl: _getFullUrl(widget.shopLogo),
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              errorWidget: (ctx, url, error) => _buildNoImagePlaceholder(ctx),
                                            )
                                          : _buildNoImagePlaceholder(context),
                                ),
                              ),
                              
                              if (hasShopInfo)
                                Text(
                                  localizedShopName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),


                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Reason Section — only when the shop cancelled the order.
                      if (!widget.cancelledByUser &&
                          widget.reason != null &&
                          widget.reason!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIcons.infoFill,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('order_cancel.reason_title'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.reason!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
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

