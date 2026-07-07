import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/coupon_service.dart';
import '../../../home/presentation/widgets/image_skeleton_loader.dart';
import 'coupon_details_sheet.dart';
import 'coupon_display.dart';

/// A horizontal rail of browseable coupons fetched from `GET /user/coupons`.
/// Used on the Home and Food tabs. Renders nothing while loading returns empty
/// (e.g. an early-bird rail for a non-early-bird user), so it never leaves a
/// blank header behind.
class CouponRailSection extends StatefulWidget {
  /// Section header label.
  final String title;

  /// API target filter: `all`, `earlybird`, or null for the default rules.
  final String? target;

  /// Leading gap above the section. Kept *inside* the widget so it collapses
  /// together with the rail when there's nothing to show (an empty rail renders
  /// nothing at all, avoiding a doubled gap between the surrounding sections).
  final double topGap;

  const CouponRailSection({
    super.key,
    required this.title,
    this.target,
    this.topGap = 24,
  });

  @override
  State<CouponRailSection> createState() => _CouponRailSectionState();
}

class _CouponRailSectionState extends State<CouponRailSection> {
  /// How many times to re-issue the request after a transient failure before
  /// giving up and hiding the rail. The Home tab fires many section requests at
  /// once, so the coupon call can occasionally fail/cancel under load.
  static const int _maxAttempts = 3;

  late Future<List<CouponModel>> _future;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _attempts++;
    // Coupons require an authenticated user (the endpoints are JWT-guarded and
    // redemption is per-user), so skip the request entirely for guests instead
    // of firing a 401 and showing a rail they can't act on.
    _future = AuthService().isLoggedIn
        ? CouponService.instance.fetchAllCoupons(target: widget.target)
        : Future.value(const <CouponModel>[]);
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isLoggedIn) return const SizedBox.shrink();
    return FutureBuilder<List<CouponModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        // A transient failure (vs a genuinely empty list) shouldn't make the
        // rail disappear: retry a couple of times before giving up.
        if (snapshot.hasError) {
          if (_attempts < _maxAttempts) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_load);
            });
            return _buildSkeleton();
          }
          return const SizedBox.shrink();
        }
        final coupons = snapshot.data ?? const [];
        if (coupons.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: widget.topGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.local_activity_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${coupons.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 136,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: coupons.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => CouponBrowseCard(
                  coupon: coupons[index],
                  expandFooter: true,
                  onTap: () =>
                      CouponDetailsSheet.show(context, coupons[index]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: widget.topGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const ImageSkeletonLoader(width: 150, height: 18),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const ImageSkeletonLoader(width: 250, height: 120),
            ),
          ),
        ),
      ],
    );
  }
}

