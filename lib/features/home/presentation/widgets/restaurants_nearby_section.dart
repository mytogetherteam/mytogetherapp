import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'restaurant_card.dart';
import 'image_skeleton_loader.dart';
import 'view_all_icon_button.dart';
import '../screens/restaurant_detail_page.dart';
import '../screens/restaurant_nearby_list_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../../../../core/location/location_service.dart';
import '../../data/fallback_data.dart';

class RestaurantsNearbySection extends StatefulWidget {
  const RestaurantsNearbySection({super.key});

  @override
  State<RestaurantsNearbySection> createState() => _RestaurantsNearbySectionState();
}

class _RestaurantsNearbySectionState extends State<RestaurantsNearbySection> {
  Future<List<Restaurant>>? _restaurantsFuture;
  final Map<String, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _restaurantsFuture = _loadNearbyRestaurants();
  }

  Future<List<Restaurant>> _loadNearbyRestaurants() async {
    try {
      final activeLoc = UserLocationRepository.instance.activeLocation;
      final pos = await LocationService().getCurrentPosition();
      
      return await RestaurantRepository.instance.getNearbyShops(
        lat: activeLoc?.latitude ?? pos.latitude,
        lon: activeLoc?.longitude ?? pos.longitude,
        radius: 10.0,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('RestaurantsNearbySection: API error or timeout: $e');
      return []; // Return empty to trigger fallback in builder
    }
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus = !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    
    // Immediate local feedback
    setState(() {
      _localFavorites[restaurant.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleShopFavorite(
        int.tryParse(restaurant.id) ?? 0,
        newStatus,
      );
      // No longer refreshing the future here to prevent flickering.
      // The local state _localFavorites handles the immediate color change.
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Added to favorites' : 'Removed from favorites'),
            backgroundColor: const Color(0xFFED3A72),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _localFavorites[restaurant.id] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to update favorite. Please try again.'),
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
        // If waiting, show skeleton
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }

        // Determine the list of restaurants (either fetched or fallback)
        final List<Restaurant> restaurants;
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          debugPrint('RestaurantsNearbySection: Error or no data, using fallback: ${snapshot.error}');
          restaurants = FallbackData.restaurants;
        } else {
          restaurants = snapshot.data!;
        }

        // Build the UI using the determined restaurants list
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Restaurants Nearby',
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
              height: 240,
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
                    deliveryTime: data.deliveryTime,
                    deliveryFee: data.deliveryFee,
                    originalDeliveryFee: data.originalDeliveryFee,
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
          ],
        );
      },
    );
  }

  // --- Skeleton: horizontal row of shimmer restaurant cards ---
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Restaurants Nearby',
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
          height: 240,
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
