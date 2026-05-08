import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../../../core/utils/navigation_controller.dart';
import '../../data/active_order_state.dart';
import '../../../../core/theme/app_colors.dart';

class OrderCancelPage extends StatelessWidget {
  final String orderId;
  final String? reason;
  final String? shopId;
  final String? shopName;
  final String? shopNameMm;
  final String? shopLogo;
  final String? shopImageUrl;

  const OrderCancelPage({
    super.key,
    required this.orderId,
    this.reason,
    this.shopId,
    this.shopName,
    this.shopNameMm,
    this.shopLogo,
    this.shopImageUrl,
  });

  void _onViewRestaurant(BuildContext context) {
    ActiveOrderState.instance.clearOrder(orderId: orderId);
    
    if (shopId != null && shopId!.isNotEmpty) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      NavigationController.instance.goToFoodTab();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantDetailPage(
            id: shopId!,
            name: shopName,
            logoPath: shopLogo,
            imagePath: shopImageUrl,
          ),
        ),
      );
    } else {
      _goHome(context);
    }
  }

  void _goHome(BuildContext context) {
    ActiveOrderState.instance.clearOrder(orderId: orderId);
    NavigationController.instance.goToFoodTab();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildNoImagePlaceholder({bool isLogo = false}) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLogo ? PhosphorIcons.storefront() : PhosphorIcons.imageBroken(),
              color: Colors.grey[400],
              size: isLogo ? 24 : 32,
            ),
            if (!isLogo) ...[
              const SizedBox(height: 8),
              Text(
                "No Image",
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
    final hasLogo = shopLogo != null && shopLogo!.isNotEmpty;
    final hasImage = shopImageUrl != null && shopImageUrl!.isNotEmpty;
    final hasShopInfo = (shopName != null && shopName!.isNotEmpty) || (shopNameMm != null && shopNameMm!.isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.x(), color: Colors.black),
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
                          PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                          color: const Color(0xFFEF4444),
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        "We're sorry!",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Your order has been cancelled by the shop. We apologize for the inconvenience.",
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
                              // Logo Section (Prioritize Logo, then Image)
                              Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[50],
                                  border: Border.all(color: Colors.grey[100]!, width: 2),
                                ),
                                child: ClipOval(
                                  child: (shopLogo != null && shopLogo!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: shopLogo!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          errorWidget: (context, url, error) => _buildNoImagePlaceholder(isLogo: true),
                                        )
                                      : (shopImageUrl != null && shopImageUrl!.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: shopImageUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              errorWidget: (context, url, error) => _buildNoImagePlaceholder(isLogo: true),
                                            )
                                          : _buildNoImagePlaceholder(isLogo: true),
                                ),
                              ),
                              
                              if (hasShopInfo) ...[
                                if (shopName != null && shopName!.isNotEmpty)
                                  Text(
                                    shopName!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                if (shopNameMm != null && shopNameMm!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      shopNameMm!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],


                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Reason Section
                      if (reason != null && reason!.isNotEmpty) ...[
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
                                    PhosphorIcons.info(PhosphorIconsStyle.fill),
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Cancellation Reason",
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
                                reason!,
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
                    "View Restaurant",
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
    );
  }
}
