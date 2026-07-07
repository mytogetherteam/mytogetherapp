import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/coupon_service.dart';

/// Short discount headline for a coupon, e.g. "40% OFF", "฿50 OFF", "FREE".
String couponDiscountLabel(BuildContext context, CouponModel coupon) {
  if (coupon.isFreeItem) {
    if (coupon.isBogoAllItems) return context.tr('coupon.bogo_all');
    return context.tr('coupon.free');
  }
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
  if (coupon.isFreeItem) {
    if (coupon.isBogoAllItems) return context.tr('coupon.bogo_on_order');
    return context.tr('coupon.offer_free');
  }
  if (coupon.isPercentage) {
    return context.trArgs('coupon.offer_percent', {
      'value': _trimNum(coupon.discountValue),
    });
  }
  return context.trArgs('coupon.offer_amount', {
    'value': _trimNum(coupon.discountValue),
  });
}

/// BOGO / gift-menu summary for the order-flow ticket and summary row.
String couponBogoGiftSummary(BuildContext context, CouponModel coupon) {
  if (!coupon.isFreeItem) return '';
  if (coupon.isBogoAllItems) return context.tr('coupon.bogo_on_order');

  final buyNames =
      coupon.buyItems.map((e) => e.name).where((e) => e.isNotEmpty);
  final freeNames =
      coupon.freeItems.map((e) => e.name).where((e) => e.isNotEmpty);

  if (buyNames.isNotEmpty && freeNames.isNotEmpty) {
    return context.trArgs('coupon.buy_get_summary', {
      'buy': buyNames.join(', '),
      'free': freeNames.join(', '),
    });
  }
  if (freeNames.isNotEmpty) {
    return context.trArgs('coupon.free_items', {'items': freeNames.join(', ')});
  }
  if (buyNames.isNotEmpty) {
    return context.trArgs('coupon.required_items_summary', {
      'items': buyNames.join(', '),
    });
  }
  return context.tr('coupon.free_item_generic');
}

String _trimNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String _couponShopName(BuildContext context, CouponModel coupon) {
  final shop = coupon.shop;
  if (shop == null) return '';
  return context.localized(
    en: shop.nameEn,
    mm: shop.nameMm,
    th: shop.nameTh,
  );
}

/// Shared browse / saved coupon card (shop row + gradient name badge + expiry).
class CouponBrowseCard extends StatelessWidget {
  final CouponModel coupon;
  final VoidCallback? onTap;

  /// Fixed width for horizontal rails; null stretches to parent width.
  final double? width;

  /// Rail cards sit in a fixed-height row and push the footer down with [Spacer].
  final bool expandFooter;

  const CouponBrowseCard({
    super.key,
    required this.coupon,
    this.onTap,
    this.width = 250,
    this.expandFooter = false,
  });

  @override
  Widget build(BuildContext context) {
    final shopName = _couponShopName(context, coupon);
    final validity = couponValidityLabel(context, coupon);

    final card = Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expandFooter ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CouponShopLogo(
                key: ValueKey('coupon_logo_${coupon.resolvedShopId}'),
                shopId: coupon.resolvedShopId,
                shopName: shopName,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shopName.isNotEmpty
                      ? shopName
                      : context.tr('coupon.all_shops'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (expandFooter) const Spacer() else const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    coupon.name.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (validity != null) ...[
                const SizedBox(width: 8),
                Text(
                  context.trArgs('coupon.until_short', {'date': validity}),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

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
    final isBogo = coupon.isBogoAllItems;
    final big = isFree
        ? (isBogo ? '1+1' : context.tr('coupon.free'))
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
            isBogo
                ? Icons.redeem_rounded
                : isFree
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
                fontWeight: FontWeight.w700,
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

