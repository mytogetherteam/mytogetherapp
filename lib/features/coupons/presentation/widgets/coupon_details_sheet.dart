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

  @override
  Widget build(BuildContext context) {
    return CouponSheetShell(child: CouponDetailsView(coupon: coupon));
  }
}

/// Shared rounded bottom-sheet chrome so the standalone [CouponDetailsSheet] and
/// the embedded shop promotions sheet render identical containers.
class CouponSheetShell extends StatelessWidget {
  final Widget child;

  const CouponSheetShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: child,
        ),
      ),
    );
  }
}

/// The inner content of a coupon details view: header, scrollable details, and
/// the Order / Use now actions. Rendered standalone inside [CouponDetailsSheet],
/// or embedded inside the shop promotions sheet — in which case [onBack] is set
/// and a back arrow returns to the list instead of a drag handle. When
/// [currentShopId] equals the coupon's shop, "Order" simply closes the sheet
/// (the user is already on that shop's page).
class CouponDetailsView extends StatelessWidget {
  final CouponModel coupon;
  final VoidCallback? onBack;
  final int? currentShopId;

  const CouponDetailsView({
    super.key,
    required this.coupon,
    this.onBack,
    this.currentShopId,
  });

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
    // Already on this shop's page → just close the sheet and stay.
    if (currentShopId != null && shopId == currentShopId) {
      Navigator.of(context).pop();
      return;
    }
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
    final validFrom = formatCouponDate(coupon.validFrom);
    final validUntil = couponValidityLabel(context, coupon);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 22, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('coupon.details_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          )
        else
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
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CouponShopLogo(
                      shopId: coupon.resolvedShopId,
                      shopName: shopName,
                      size: 54,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName.isNotEmpty ? shopName : context.tr('coupon.all_shops'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            coupon.name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (coupon.isEarlyBird) const _EarlyBirdTag(),
                  ],
                ),
                const SizedBox(height: 16),
                _OfferBanner(label: couponOfferLabel(context, coupon)),
                if (coupon.isBogoAllItems) ...[
                  const SizedBox(height: 10),
                  Text(
                    context.tr('coupon.bogo_on_order'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if ((coupon.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    coupon.description!.trim(),
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Colors.black.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if (coupon.buyItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ItemsBlock(
                    title: context.tr('coupon.required_items'),
                    icon: Icons.shopping_bag_outlined,
                    items: coupon.buyItems,
                  ),
                ],
                if (coupon.freeItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ItemsBlock(
                    title: context.tr('coupon.free_items_title'),
                    icon: Icons.card_giftcard_rounded,
                    items: coupon.freeItems,
                    highlight: true,
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEDEDED)),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.groups_outlined,
                  label: context.tr('coupon.eligibility'),
                  value: coupon.isEarlyBird
                      ? context.tr('coupon.for_early_bird')
                      : context.tr('coupon.for_everyone'),
                ),
                if (validFrom != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.play_circle_outline_rounded,
                    label: context.tr('coupon.valid_from'),
                    value: validFrom,
                  ),
                ],
                if (validUntil != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.event_busy_outlined,
                    label: context.tr('coupon.valid_until'),
                    value: validUntil,
                  ),
                ],
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.repeat_rounded,
                  label: context.tr('coupon.usage'),
                  value: coupon.limitType.toUpperCase() == 'ONE_TIME'
                      ? context.tr('coupon.one_time')
                      : context.tr('coupon.reusable'),
                  isHighlight: true,
                ),
                const SizedBox(height: 16),
                const _HowToUse(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: coupon.resolvedShopId == null
                    ? null
                    : () => _onOrder(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                label: Text(
                  'Order Online',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _onUseNow(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 20),
              label: Text(
                'Scan QR at Shop',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
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

class _OfferBanner extends StatelessWidget {
  final String label;
  const _OfferBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Row(
          children: [
            const Icon(Icons.discount_rounded, size: 22, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<CouponItem> items;
  final bool highlight;

  const _ItemsBlock({
    required this.title,
    required this.icon,
    required this.items,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.05)
            : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
                  Icon(icon,
                      size: 15,
                      color:
                          highlight ? AppColors.primary : Colors.grey.shade500),
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

class _HowToUse extends StatelessWidget {
  const _HowToUse();

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
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                context.tr('coupon.how_to_use'),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Tap 'Order Online' to use it on a delivery order, or 'Scan QR at Shop' to redeem it in-store.",
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade600,
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
  final bool isHighlight;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlight = false,
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
          child: isHighlight
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(
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
