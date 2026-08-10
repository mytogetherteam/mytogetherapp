import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'restaurant_card.dart';
import 'image_skeleton_loader.dart';
import 'view_all_icon_button.dart';
import '../screens/restaurant_detail_page.dart';
import '../screens/restaurant_nearby_list_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_refresh_mixin.dart';

class RestaurantsNearbySection extends StatefulWidget {
  const RestaurantsNearbySection({super.key});

  @override
  State<RestaurantsNearbySection> createState() => _RestaurantsNearbySectionState();
}

class _RestaurantsNearbySectionState extends State<RestaurantsNearbySection>
    with LocationRefreshMixin {
  Future<List<Restaurant>>? _restaurantsFuture;
  final Map<String, bool> _localFavorites = {};

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
      _restaurantsFuture = _loadNearbyRestaurants();
    });
  }

  Future<List<Restaurant>> _loadNearbyRestaurants() async {
    try {
      // Shared resolver keeps this in sync with the nearby map page and food
      // search (saved active location → device GPS → default).
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();

      return await RestaurantRepository.instance.getNearbyShops(
        lat: coords.lat,
        lon: coords.lon,
        radius: 5.0,
        size: 10,
        deliveryOnly: true,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('RestaurantsNearbySection: API error or timeout: $e');
      return [];
    }
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus = !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    
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
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('common.favorite_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _restaurantsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(context);
        }

        final List<Restaurant> restaurants = (snapshot.data ?? []).take(10).toList();

        // If empty or error — show nothing (no hardcoded fallback)
        if (restaurants.isEmpty) {
          debugPrint('RestaurantsNearbySection: No data from API, hiding section.');
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('home.restaurants_nearby'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  ViewAllIconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RestaurantNearbyListPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 232,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: restaurants.length,
                itemBuilder: (context, index) {
                  final data = restaurants[index];

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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RestaurantDetailPage(
                            id: data.id,
                            name: data.name,
                            category: data.category,
                            rating: data.rating,
                            distance: data.distance,
                            imagePath: data.imagePath,
                            logoPath: data.logoPath,
                            deliveryTime: data.deliveryTime,
                            status: data.status,
                            isFavorite: _localFavorites[data.id] ?? data.isFavorite,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // --- Skeleton: horizontal row of shimmer restaurant cards ---
  Widget _buildSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('home.restaurants_nearby'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 232,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (_, index) => Container(
              width: 190,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const ImageSkeletonLoader(height: 155),
                  ),
                  const SizedBox(height: 10),
                  _shimmerBox(width: 130, height: 14, radius: 6),
                  const SizedBox(height: 6),
                  _shimmerBox(width: 90, height: 12, radius: 6),
                  const SizedBox(height: 6),
                  _shimmerBox(width: 70, height: 12, radius: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({required double width, required double height, double radius = 8}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ImageSkeletonLoader(width: width, height: height),
    );
  }
}
