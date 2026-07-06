import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../cart/data/order_shop_coupon_info.dart';

/// Coupon discount row for post-checkout order screens (tracking, status, etc.).
class OrderCouponDiscountSection extends StatelessWidget {
  final String? couponName;
  final double discountAmount;
  final String? displayDiscountAmount;
  final OrderShopCouponInfo? shopCoupon;

  const OrderCouponDiscountSection({
    super.key,
    this.couponName,
    this.discountAmount = 0,
    this.displayDiscountAmount,
    this.shopCoupon,
  });

  bool get _visible =>
      discountAmount > 0 ||
      shopCoupon?.isFreeItem == true ||
      (couponName?.trim().isNotEmpty ?? false);

  String _amountText(BuildContext context) {
    if (discountAmount > 0) {
      final raw = displayDiscountAmount?.trim();
      if (raw != null && raw.isNotEmpty) {
        return '- ${raw.toFormattedPrice()}';
      }
      return '- ${discountAmount.toFormattedPrice()}';
    }
    if (shopCoupon?.isFreeItem == true) {
      return context.tr('coupon.free');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final label = couponName?.trim().isNotEmpty == true
        ? couponName!.trim()
        : context.tr('order_status.discount');
    final hint = shopCoupon?.itemsHint(context) ?? '';
    final amount = _amountText(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (amount.isNotEmpty)
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }
}
