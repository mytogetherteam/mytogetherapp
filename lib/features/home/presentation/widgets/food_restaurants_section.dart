import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'restaurant_card.dart';
import 'image_skeleton_loader.dart';
import 'view_all_icon_button.dart';
import 'restaurant_ordering_filter_chips.dart';
import '../screens/restaurant_detail_page.dart';
import '../screens/all_restaurants_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_refresh_mixin.dart';

class FoodRestaurantsSection extends StatefulWidget {
  const FoodRestaurantsSection({super.key});

  @override
  State<FoodRestaurantsSection> createState() => _FoodRestaurantsSectionState();
}

class _FoodRestaurantsSectionState extends State<FoodRestaurantsSection>
    with LocationRefreshMixin {
  Future<List<Restaurant>>? _restaurantsFuture;
  final Map<String, bool> _localFavorites = {};
  RestaurantOrderingFilter _filter = RestaurantOrderingFilter.delivery;

  @override
  void initState() {
    super.initState();
    _reloadRestaurants();
  }

  @override
  void onActiveLocationChanged() {
    _reloadRestaurants();
  }

  void _reloadRestaurants() {
    setState(() {
      _restaurantsFuture = _loadRestaurants();
    });
  }

  Future<List<Restaurant>> _loadRestaurants() async {
    try {
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();

      // Fetch unfiltered so we can split Delivery vs Visit only in the UI.
      return await RestaurantRepository.instance
          .getNearbyShops(
            lat: coords.lat,
            lon: coords.lon,
            radius: 20.0,
            size: 40,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('FoodRestaurantsSection: API error: $e');
      return [];
    }
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus =
        !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
    setState(() {
      _localFavorites[restaurant.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleShopFavorite(
        int.tryParse(restaurant.id) ?? 0,
        newStatus,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _localFavorites[restaurant.id] = !newStatus;
        });
      }
    }
  }

  List<Restaurant> _filtered(List<Restaurant> all) {
    final filtered = _filter == RestaurantOrderingFilter.delivery
        ? RestaurantRepository.filterDeliveryEnabled(all)
        : RestaurantRepository.filterVisitOnly(all);
    return filtered.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _restaurantsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(context);
        }

        final List<Restaurant> allRestaurants = snapshot.data ?? [];
        if (allRestaurants.isEmpty) return const SizedBox.shrink();

        final displayRestaurants = _filtered(allRestaurants);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('food.restaurants'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  ViewAllIconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllRestaurantsPage(
                            visitOnly:
                                _filter == RestaurantOrderingFilter.visitOnly,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RestaurantOrderingFilterChips(
              selected: _filter,
              onChanged: (value) {
                if (value == _filter) return;
                setState(() => _filter = value);
              },
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            const SizedBox(height: 16),
            if (displayRestaurants.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  context.tr(
                    _filter == RestaurantOrderingFilter.delivery
                        ? 'restaurants.empty_delivery'
                        : 'restaurants.empty_visit_only',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: displayRestaurants.length,
                  itemBuilder: (context, index) {
                    final data = displayRestaurants[index];
                    return RestaurantCard(
                      name: data.name,
                      category: data.category,
                      rating: data.rating,
                      reviewCount: data.reviewCount,
                      distance: data.distance,
                      imagePath: data.imagePath,
                      logoPath: data.logoPath,
                      deliveryTime: data.deliveryTime,
                      deliveryFee: data.deliveryFee,
                      originalDeliveryFee: data.originalDeliveryFee,
                      deliveryEnabled: data.deliveryEnabled,
                      operatingHours: data.operatingHours,
                      status: data.status,
                      shopId: data.id,
                      isVerified: data.isVerified,
                      isFavorite: _localFavorites[data.id] ?? data.isFavorite,
                      onFavoriteToggle: () => _toggleFavorite(data),
                      width: double.infinity,
                      margin: const EdgeInsets.only(
                        bottom: 20,
                        left: 10,
                        right: 10,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantDetailPage(
                              id: data.id,
                              name: data.name,
                              category: data.category,
                              rating: data.rating,
                              reviewCount: data.reviewCount,
                              distance: data.distance,
                              imagePath: data.imagePath,
                              logoPath: data.logoPath,
                              deliveryTime: data.deliveryTime,
                              status: data.status,
                              isFavorite:
                                  _localFavorites[data.id] ?? data.isFavorite,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            context.tr('food.restaurants'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const RestaurantOrderingFilterChips(
          selected: RestaurantOrderingFilter.delivery,
          onChanged: _noopFilter,
          padding: EdgeInsets.symmetric(horizontal: 20),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: 3,
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 16, left: 10, right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const ImageSkeletonLoader(height: 160),
                ),
                const SizedBox(height: 12),
                const ImageSkeletonLoader(width: 180, height: 16),
                const SizedBox(height: 8),
                const ImageSkeletonLoader(width: 120, height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static void _noopFilter(RestaurantOrderingFilter _) {}
}
