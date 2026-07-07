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

class _PromoCard extends StatelessWidget {
  final CouponModel coupon;
  final VoidCallback onTap;

  const _PromoCard({required this.coupon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final validity = couponValidityLabel(context, coupon);
    final discountText = couponDiscountLabel(context, coupon);
    final hasDesc = coupon.description != null && coupon.description!.trim().isNotEmpty;
    
    final gradient = AppColors.primaryGradient;
    final borderColor = AppColors.primary.withOpacity(0.4);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 85),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: const CouponShapeBorder(
            holePosition: 36.75, // Centered on dashed line (36 width + 0.75 half dashed width)
            holeRadius: 6.5,
            borderRadius: 8.0,
          ),
          shadows: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: const CouponShapeBorder(
              holePosition: 36.75,
              holeRadius: 6.5,
              borderRadius: 8.0,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left strip (Rotated 'COUPON')
                SizedBox(
                  width: 36,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'COUPON',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Vertical Dashed separator
                SizedBox(
                  width: 1.5,
                  child: CustomPaint(
                    painter: _DashedLinePainter(color: borderColor),
                  ),
                ),

                // Middle (Title + Description)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          coupon.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasDesc) ...[
                          const SizedBox(height: 4),
                          Text(
                            coupon.description!,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (validity != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  context.trArgs('coupon.until_short', {'date': validity}),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
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
                ),

                // Far Right (Discount Amount + Use text with Gradient Background)
                Container(
                  width: 100, // slightly wider to fit text comfortably
                  decoration: BoxDecoration(
                    gradient: gradient,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        discountText,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

class CouponShapeBorder extends ShapeBorder {
  final double holeRadius;
  final double holePosition;
  final double borderRadius;

  const CouponShapeBorder({
    this.holeRadius = 7.0, 
    this.holePosition = 36.0,
    this.borderRadius = 8.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    // Top left
    path.moveTo(borderRadius, 0);
    
    // Top edge and top cutout
    path.lineTo(holePosition - holeRadius, 0);
    path.arcToPoint(
      Offset(holePosition + holeRadius, 0),
      radius: Radius.circular(holeRadius),
      clockwise: false,
    );
    path.lineTo(rect.width - borderRadius, 0);
    
    // Top right
    path.arcToPoint(
      Offset(rect.width, borderRadius),
      radius: Radius.circular(borderRadius),
    );
    
    // Right edge
    path.lineTo(rect.width, rect.height - borderRadius);
    
    // Bottom right
    path.arcToPoint(
      Offset(rect.width - borderRadius, rect.height),
      radius: Radius.circular(borderRadius),
    );
    
    // Bottom edge and bottom cutout
    path.lineTo(holePosition + holeRadius, rect.height);
    path.arcToPoint(
      Offset(holePosition - holeRadius, rect.height),
      radius: Radius.circular(holeRadius),
      clockwise: false,
    );
    path.lineTo(borderRadius, rect.height);
    
    // Bottom left
    path.arcToPoint(
      Offset(0, rect.height - borderRadius),
      radius: Radius.circular(borderRadius),
    );
    
    // Left edge
    path.lineTo(0, borderRadius);
    
    // Close back to top left
    path.arcToPoint(
      Offset(borderRadius, 0),
      radius: Radius.circular(borderRadius),
    );
    
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashHeight = 4, dashSpace = 3, startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

