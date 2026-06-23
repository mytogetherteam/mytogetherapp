import 'package:flutter/material.dart';
import '../../../../core/location/location_refresh_mixin.dart';
import '../../data/geo_feed_availability.dart';
import 'food_categories_section.dart';
import 'restaurants_nearby_section.dart';
import 'popular_brands_section.dart';
import 'todays_overview_section.dart';
import 'lost_items_nearby_section.dart';
import 'top_places_nearby_section.dart';
import 'home_nothing_here_card.dart';
import 'image_skeleton_loader.dart';

/// Location-scoped home feeds (menu categories, nearby, trending, places).
/// Shows a single empty card when the user is outside Thailand, when both
/// probes return no items, or when either probe API fails.
/// Does not affect discount/collection rails on the Food tab.
class HomeLocationFeedsSection extends StatefulWidget {
  final Object refreshKey;

  const HomeLocationFeedsSection({super.key, required this.refreshKey});

  @override
  State<HomeLocationFeedsSection> createState() =>
      _HomeLocationFeedsSectionState();
}

class _HomeLocationFeedsSectionState extends State<HomeLocationFeedsSection>
    with LocationRefreshMixin {
  Future<bool>? _hasFeedsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant HomeLocationFeedsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _hasFeedsFuture = _evaluateGeoFeeds();
    });
  }

  @override
  void onActiveLocationChanged() {
    _reload();
  }

  /// Returns `true` when geo feeds should render; `false` for the empty card.
  Future<bool> _evaluateGeoFeeds() => GeoFeedAvailability.hasLocationFeeds();

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoodCategoriesSection(key: ValueKey('categories_$keyToken')),
            RestaurantsNearbySection(key: ValueKey('nearby_$keyToken')),
            PopularBrandsSection(key: ValueKey('brands_$keyToken')),
            TodaysOverviewSection(key: ValueKey('overview_$keyToken')),
            const SizedBox(height: 24),
            LostItemsNearbySection(key: ValueKey('lost_$keyToken')),
            const SizedBox(height: 24),
            TopPlacesNearbySection(key: ValueKey('places_$keyToken')),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
