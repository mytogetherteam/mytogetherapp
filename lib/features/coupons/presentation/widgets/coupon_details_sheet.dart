import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/coupon_service.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import 'coupon_display.dart';
import 'redeem_qr_sheet.dart';

/// Bottom sheet that shows full details for a browseable coupon, plus two
/// actions: "Order" (go to the shop's detail page to order online) and
/// "Use now" (show the in-shop redeem QR).
class CouponDetailsSheet extends StatelessWidget {
  final CouponModel coupon;

  const CouponDetailsSheet({super.key, required this.coupon});

  static Future<void> show(BuildContext context, CouponModel coupon) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CouponDetailsSheet(coupon: coupon),
    );
  }

  String _shopName(BuildContext context) {
    final shop = coupon.shop;
    if (shop == null) return '';
    return context.localized(
      en: shop.nameEn,
      mm: shop.nameMm,
      th: shop.nameTh,
    );
  }

  void _onOrder(BuildContext context) {
    final shopId = coupon.resolvedShopId;
    if (shopId == null) return;
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailPage(
          id: shopId.toString(),
          name: _shopName(context),
        ),
      ),
    );
  }

  void _onUseNow(BuildContext context) {
    RedeemQrSheet.show(context, couponName: coupon.name);
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _shopName(context);
    final validity = couponValidityLabel(context, coupon);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CouponHeadlineBadge(coupon: coupon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (shopName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.storefront_rounded,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                shopName,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (coupon.isEarlyBird) const _EarlyBirdTag(),
              ],
            ),
            if ((coupon.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                coupon.description!.trim(),
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ],
            if (coupon.freeItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _FreeItemsBlock(items: coupon.freeItems),
            ],
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.confirmation_number_outlined,
              label: context.tr('coupon.code'),
              value: coupon.code,
            ),
            if (validity != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.event_outlined,
                label: context.tr('coupon.valid_until'),
                value: validity,
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: coupon.resolvedShopId == null
                        ? null
                        : () => _onOrder(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      context.tr('coupon.order'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onUseNow(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: Text(
                      context.tr('coupon.use_now'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarlyBirdTag extends StatelessWidget {
  const _EarlyBirdTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🐦', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            context.tr('coupon.early_bird'),
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB26A00),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeItemsBlock extends StatelessWidget {
  final List<CouponItem> items;
  const _FreeItemsBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('coupon.free_items_title'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i.name,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    'x${i.quantity}',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
