import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/home/data/geo_feed_availability.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/explore_menu_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_categories_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_feed_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_restaurants_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/home_nothing_here_card.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/image_skeleton_loader.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/popular_brands_section.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/trending_shops_section.dart';
import '../../../../core/location/location_refresh_mixin.dart';

/// Location-scoped Food tab feeds. Discount/collection rails stay outside this
/// wrapper so they always load independently of geo probes.
class FoodLocationFeedsSection extends StatefulWidget {
  final double latitude;
  final double longitude;
  final Object refreshKey;
  final ScrollController exploreScrollController;

  const FoodLocationFeedsSection({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.refreshKey,
    required this.exploreScrollController,
  });

  @override
  State<FoodLocationFeedsSection> createState() =>
      _FoodLocationFeedsSectionState();
}

class _FoodLocationFeedsSectionState extends State<FoodLocationFeedsSection>
    with LocationRefreshMixin {
  Future<bool>? _hasFeedsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant FoodLocationFeedsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _hasFeedsFuture = GeoFeedAvailability.hasLocationFeeds();
    });
  }

  @override
  void onActiveLocationChanged() {
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasFeedsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            !snapshot.hasError) {
          return _buildLoadingPlaceholder();
        }

        final hasFeeds = !snapshot.hasError && (snapshot.data ?? false);
        if (!hasFeeds) {
          return const HomeNothingHereCard();
        }

        final keyToken = widget.refreshKey.toString();
        final lat = widget.latitude;
        final lon = widget.longitude;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FoodCategoriesSection(),
            const SizedBox(height: 16),
            const FoodRestaurantsSection(),
            const TrendingShopsSection(),
            PopularBrandsSection(
              key: ValueKey('food_brands_$keyToken'),
              title: context.tr('food.popular'),
            ),
            const SizedBox(height: 24),
            FoodFeedSection(
              key: ValueKey('foryou_${lat}_$lon'),
              feedType: 'for-you',
              title: context.tr('food.for_you'),
              latitude: lat,
              longitude: lon,
              layoutType: 2,
            ),
            ExploreMenuSection(
              key: ValueKey('explore_${lat}_$lon'),
              title: context.tr('food.explore_menu'),
              latitude: lat,
              longitude: lon,
              scrollController: widget.exploreScrollController,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const ImageSkeletonLoader(width: 160, height: 20),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => ClipOval(
                child: const ImageSkeletonLoader(width: 72, height: 72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
