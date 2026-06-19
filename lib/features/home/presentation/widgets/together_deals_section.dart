import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'view_all_icon_button.dart';
import 'image_skeleton_loader.dart';
import 'discount_deal_card.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/today_overview_detail_page.dart';

class TogetherDealsSection extends StatefulWidget {
  /// When true, the section header uses [DiscountDealsDto.sectionTitle] from
  /// `GET /api/user/menu-items/discount` (e.g. "Summer 30% Off").
  final bool useApiSectionTitle;

  /// Called when the discount API returns a non-empty [sectionTitle].
  final ValueChanged<String>? onSectionTitleLoaded;

  const TogetherDealsSection({
    super.key,
    this.useApiSectionTitle = false,
    this.onSectionTitleLoaded,
  });

  @override
  State<TogetherDealsSection> createState() => _TogetherDealsSectionState();
}

class _TogetherDealsSectionState extends State<TogetherDealsSection> {
  // Fallback headline percentage when the API doesn't report a max discount.
  static const int _fallbackMaxPercent = 40;

  Future<DiscountDealsDto>? _dealsFuture;

  @override
  void initState() {
    super.initState();
    _dealsFuture = _loadDeals();
  }

  Future<DiscountDealsDto> _loadDeals() async {
    try {
      final activeLoc = UserLocationRepository.instance.activeLocation;
      final pos = await LocationService().getCurrentPosition();
      final lat = activeLoc?.latitude ?? pos.latitude;
      final lon = activeLoc?.longitude ?? pos.longitude;

      // Preferred: the dedicated discount carousel endpoint (auth + location).
      if (AuthService().isLoggedIn) {
        final deals = await RestaurantRepository.instance
            .getDiscountDeals(lat: lat, lon: lon, size: 10)
            .timeout(const Duration(seconds: 5));
        final title = deals.sectionTitle.trim();
        if (title.isNotEmpty) {
          widget.onSectionTitleLoaded?.call(title);
        }
        if (deals.items.isNotEmpty) return deals;
      }

      // When discount endpoint returns nothing, try the hot-deals food-tab feed
      // (also backed by user menu-items/discount data).
      final fallback = await RestaurantRepository.instance
          .getFoodTabFeed(
            feedType: 'hot-deals',
            lat: lat,
            lon: lon,
            size: 10,
          )
          .timeout(const Duration(seconds: 5));
      return DiscountDealsDto(
        sectionTitle: '',
        maxDiscountPercentage: 0,
        items: fallback.items,
      );
    } catch (e) {
      debugPrint('TogetherDealsSection: API error: $e');
      return DiscountDealsDto(
        sectionTitle: '',
        maxDiscountPercentage: 0,
        items: const [],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiscountDealsDto>(
      future: _dealsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }

        final deals = (snapshot.data?.items ?? []).take(10).toList();
        if (deals.isEmpty) return const SizedBox.shrink();

        final maxPercent = (snapshot.data?.maxDiscountPercentage ?? 0) > 0
            ? snapshot.data!.maxDiscountPercentage
            : _fallbackMaxPercent;
        final apiSectionTitle = snapshot.data?.sectionTitle.trim() ?? '';
        final headerTitle = widget.useApiSectionTitle
            ? (apiSectionTitle.isNotEmpty
                ? apiSectionTitle
                : context.tr('food.discount'))
            : context.tr('home.together_deals');
        // Title shown on the detail page. When the header is the composed
        // "Together Up to X% Off" headline, mirror that exact wording instead
        // of the generic "Together Deals" label.
        final detailTitle = widget.useApiSectionTitle
            ? headerTitle
            : '${context.tr('home.together_prefix')}'
                    '${context.trArgs('home.up_to_off_pct', {'percent': '$maxPercent'})}'
                .trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: widget.useApiSectionTitle
                        ? Text(
                            headerTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: context.tr('home.together_prefix'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GradientText(
                                    context.trArgs('home.up_to_off_pct',
                                        {'percent': '$maxPercent'}),
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Text(
                                    '✦',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  ViewAllIconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TodayOverviewDetailPage(
                            feedType: 'hot-deals',
                            title: detailTitle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Horizontal scroll cards
            SizedBox(
              height: 224,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 20),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.useApiSectionTitle
                    ? context.tr('food.discount')
                    : context.tr('home.together_deals'),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 20),
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


