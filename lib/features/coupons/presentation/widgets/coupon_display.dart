import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/coupon_service.dart';

/// Short discount headline for a coupon, e.g. "40% OFF", "฿50 OFF", "FREE".
String couponDiscountLabel(BuildContext context, CouponModel coupon) {
  if (coupon.isFreeItem) return context.tr('coupon.free');
  if (coupon.isPercentage) {
    return context.trArgs('coupon.percent_off', {
      'value': _trimNum(coupon.discountValue),
    });
  }
  return context.trArgs('coupon.amount_off', {
    'value': _trimNum(coupon.discountValue),
  });
}

/// Human-readable "valid until" date, or null when not available.
String? couponValidityLabel(BuildContext context, CouponModel coupon) {
  final d = coupon.validUntil;
  if (d == null) return null;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = d.toLocal();
  final m = (local.month >= 1 && local.month <= 12) ? months[local.month - 1] : '';
  return '${local.day} $m ${local.year}';
}

String _trimNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The gradient discount badge shown on coupon cards and the details sheet.
class CouponHeadlineBadge extends StatelessWidget {
  final CouponModel coupon;
  final double size;

  const CouponHeadlineBadge({
    super.key,
    required this.coupon,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = coupon.isFreeItem;
    final big = isFree
        ? context.tr('coupon.free')
        : coupon.isPercentage
            ? '${_trimNum(coupon.discountValue)}%'
            : '฿${_trimNum(coupon.discountValue)}';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFree
                ? Icons.card_giftcard_rounded
                : Icons.local_offer_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 16,
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              big,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
