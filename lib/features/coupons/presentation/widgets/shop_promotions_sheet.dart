import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/coupon_service.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import 'coupon_details_sheet.dart';
import 'coupon_display.dart';

/// A single bottom sheet for a restaurant's promotions/coupons.
///
/// It hosts both the coupon list and the per-coupon details *inside the same
/// sheet* — tapping a coupon swaps the content in place (with a back arrow),
/// so the user never sees two stacked bottom sheets.
class ShopPromotionsSheet extends StatefulWidget {
  final int shopId;
  final String shopName;

  const ShopPromotionsSheet({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  static Future<void> show(
    BuildContext context, {
    required int shopId,
    required String shopName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopPromotionsSheet(shopId: shopId, shopName: shopName),
    );
  }

  @override
  State<ShopPromotionsSheet> createState() => _ShopPromotionsSheetState();
}

class _ShopPromotionsSheetState extends State<ShopPromotionsSheet> {
  late final Future<List<CouponModel>> _future;
  CouponModel? _selected;

  @override
  void initState() {
    super.initState();
    // Coupon endpoints are JWT-guarded; skip the call for guests entirely.
    _future = AuthService().isLoggedIn
        ? CouponService.instance.fetchByShop(widget.shopId)
        : Future.value(const <CouponModel>[]);
  }

  @override
  Widget build(BuildContext context) {
    return CouponSheetShell(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: _selected == null
            ? _buildList(context)
            : KeyedSubtree(
                key: ValueKey('details_${_selected!.id}'),
                child: CouponDetailsView(
                  coupon: _selected!,
                  currentShopId: widget.shopId,
                  onBack: () => setState(() => _selected = null),
                ),
              ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      key: const ValueKey('list'),
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
          children: [
            Icon(Icons.local_activity_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('coupon.promotions_title'),
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.shopName.trim().isNotEmpty)
                    Text(
                      widget.shopName,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Flexible(
          child: FutureBuilder<List<CouponModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (!AuthService().isLoggedIn) {
                return _EmptyState(
                  icon: Icons.lock_outline_rounded,
                  message: context.tr('coupon.promotions_login'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeleton();
              }
              final coupons = snapshot.data ?? const <CouponModel>[];
              if (coupons.isEmpty) {
                return _EmptyState(
                  icon: Icons.local_activity_outlined,
                  message: context.tr('coupon.promotions_empty'),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: coupons.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _PromoCard(
                  coupon: coupons[index],
                  onTap: () => setState(() => _selected = coupons[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: const ImageSkeletonLoader(width: double.infinity, height: 84),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    // Reserve a consistent block of height so the message is vertically
    // centered in the sheet instead of hugging the header. Mirrors the rough
    // height of the loaded/skeleton state so the sheet doesn't jump in size.
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountPill extends StatelessWidget {
  final String label;
  const _DiscountPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final CouponModel coupon;
  final VoidCallback onTap;

  const _PromoCard({required this.coupon, required this.onTap});

  String _shopName(BuildContext context) {
    final shop = coupon.shop;
    if (shop == null) return '';
    return context.localized(
      en: shop.nameEn,
      mm: shop.nameMm,
      th: shop.nameTh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _shopName(context);
    final validity = couponValidityLabel(context, coupon);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Row(
          children: [
            CouponShopLogo(
              key: ValueKey('promo_logo_${coupon.resolvedShopId}'),
              shopId: coupon.resolvedShopId,
              shopName: shopName,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _DiscountPill(label: couponDiscountLabel(context, coupon)),
                  if (validity != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.trArgs('coupon.until_short', {'date': validity}),
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
