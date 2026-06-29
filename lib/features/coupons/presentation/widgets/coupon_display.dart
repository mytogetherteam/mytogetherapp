import 'package:cached_network_image/cached_network_image.dart';
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
String? couponValidityLabel(BuildContext context, CouponModel coupon) =>
    formatCouponDate(coupon.validUntil);

/// Formats a date as e.g. "30 Jul 2026", or null when not available.
String? formatCouponDate(DateTime? d) {
  if (d == null) return null;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = d.toLocal();
  final m =
      (local.month >= 1 && local.month <= 12) ? months[local.month - 1] : '';
  return '${local.day} $m ${local.year}';
}

/// A full sentence describing what the coupon gives, e.g. "10% off your order".
String couponOfferLabel(BuildContext context, CouponModel coupon) {
  if (coupon.isFreeItem) return context.tr('coupon.offer_free');
  if (coupon.isPercentage) {
    return context.trArgs('coupon.offer_percent', {
      'value': _trimNum(coupon.discountValue),
    });
  }
  return context.trArgs('coupon.offer_amount', {
    'value': _trimNum(coupon.discountValue),
  });
}

String _trimNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The shop's circular logo, resolved client-side via the shop-profile endpoint
/// (the coupon list doesn't include it). Falls back to a letter avatar.
class CouponShopLogo extends StatelessWidget {
  final int? shopId;
  final String? shopName;
  final double size;

  const CouponShopLogo({
    super.key,
    required this.shopId,
    this.shopName,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final id = shopId;
    if (id == null) return _fallback();
    return FutureBuilder<String?>(
      future: CouponService.instance.fetchShopLogo(id),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return _fallback();
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, _) => _fallback(),
            errorWidget: (_, _, _) => _fallback(),
          ),
        );
      },
    );
  }

  Widget _fallback() {
    final name = (shopName ?? '').trim();
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '#';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.poppins(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

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
