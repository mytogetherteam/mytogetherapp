import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../data/models/home_discount_section_dto.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../screens/today_overview_detail_page.dart';
import '../../../../core/location/location_refresh_mixin.dart';
import 'discount_deal_card.dart';
import 'image_skeleton_loader.dart';
import 'view_all_icon_button.dart';

/// Home discount carousel driven entirely by the admin-controlled config from
/// `GET /api/user/home-discount-section`.
///
/// Flow (see also the backend contract):
///   1. Load the section config.
///   2. Only continue if `activeSection.status == "active"`.
///   3. Resolve the user location (saved active location or a real GPS fix).
///   4. Load discount items from `GET /api/user/menu-items/discount` using the
///      config's `discountPercent` (and `title` as `sectionTitle` when set).
///   5. Render the carousel using the API's `sectionTitle` for the header.
///
/// The whole section is hidden (renders nothing) when any precondition fails:
/// no sections, no active section, scheduled/expired, no location, or no items.
class HomeDiscountSection extends StatefulWidget {
  const HomeDiscountSection({super.key});

  @override
  State<HomeDiscountSection> createState() => _HomeDiscountSectionState();
}

class _HomeDiscountSectionState extends State<HomeDiscountSection>
    with LocationRefreshMixin {
  Future<_HomeDiscountData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void onActiveLocationChanged() {
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<_HomeDiscountData> _load() async {
    try {
      final config = await RestaurantRepository.instance
          .getHomeDiscountSectionConfig()
          .timeout(const Duration(seconds: 5));

      final active = config.activeSection;
      // Conditions 2 & 3: an active section must exist and be running.
      if (active == null || !active.isActive) {
        return const _HomeDiscountData.hidden();
      }

      // Condition 4: a real user location must be available. We never fall back
      // to a default location for the discount carousel.
      final location = await _resolveLocation();
      if (location == null) {
        return const _HomeDiscountData.hidden();
      }

      final deals = await RestaurantRepository.instance
          .getDiscountDeals(
            lat: location.lat,
            lon: location.lon,
            percentage: active.discountPercent,
            size: 8,
            // Pass the configured title verbatim (incl. any `{}` placeholder).
            // Omit it when null/empty so the backend uses its default title.
            sectionTitle: active.hasTitle ? active.title : null,
          )
          .timeout(const Duration(seconds: 5));

      // Condition 5: hide an empty carousel.
      if (deals.items.isEmpty) {
        return const _HomeDiscountData.hidden();
      }

      return _HomeDiscountData.visible(active: active, deals: deals);
    } catch (e) {
      debugPrint('HomeDiscountSection: load error: $e');
      return const _HomeDiscountData.hidden();
    }
  }

  /// Returns the location to use, preferring a saved active location and falling
  /// back to a real GPS fix. Returns null when no real location is available
  /// (the [LocationService] default/fallback position is intentionally ignored).
  Future<_LatLng?> _resolveLocation() async {
    final coords =
        await UserLocationRepository.instance.resolveActiveCoordinates();
    return _LatLng(coords.lat, coords.lon);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeDiscountData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }

        final data = snapshot.data;
        if (data == null || !data.visible) {
          return const SizedBox.shrink();
        }

        final deals = data.deals!.items
            .take(8)
            .toList();
        final apiTitle = data.deals!.sectionTitle.trim();
        final headerTitle = apiTitle.isNotEmpty
            ? apiTitle
            : context.tr('food.discount');
        final maxPercent = data.deals!.maxDiscountPercentage > 0
            ? data.deals!.maxDiscountPercentage
            : data.active!.discountPercent;
        final showViewAll = data.deals!.totalCount > 8;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            headerTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (maxPercent > 0) ...[
                          const SizedBox(width: 8),
                          _UpToBadge(percent: maxPercent),
                        ],
                      ],
                    ),
                  ),
                  if (showViewAll)
                    ViewAllIconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TodayOverviewDetailPage(
                              feedType: 'hot-deals',
                              title: headerTitle,
                              discountPercentage: data.active!.discountPercent,
                              discountSectionTitle: data.active!.hasTitle
                                  ? data.active!.title
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 224,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 16),
                itemCount: deals.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    DiscountDealCard(deal: deals[index]),
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
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const ImageSkeletonLoader(width: 160, height: 18),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 16),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: const ImageSkeletonLoader(
                      width: 130,
                      height: 120,
                      showLogo: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 60, height: 14),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 100, height: 12),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 90, height: 11),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 80, height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpToBadge extends StatelessWidget {
  final int percent;
  const _UpToBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.trArgs('home.up_to_off_pct', {'percent': '$percent'}).trim(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LatLng {
  final double lat;
  final double lon;
  const _LatLng(this.lat, this.lon);
}

/// Immutable result of the two-step load: either hidden or a visible carousel.
class _HomeDiscountData {
  final bool visible;
  final HomeDiscountSectionDto? active;
  final DiscountDealsDto? deals;

  const _HomeDiscountData._({
    required this.visible,
    this.active,
    this.deals,
  });

  const _HomeDiscountData.hidden() : this._(visible: false);

  const _HomeDiscountData.visible({
    required HomeDiscountSectionDto active,
    required DiscountDealsDto deals,
  }) : this._(visible: true, active: active, deals: deals);
}
