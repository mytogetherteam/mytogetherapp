import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../auth/data/repositories/user_location_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../screens/restaurant_detail_page.dart';
import 'image_skeleton_loader.dart';
import 'restaurant_card.dart';

/// Horizontal "Trending Now" rail backed by
/// `GET /api/user/shop-profile/trending` (shops ranked by completed orders).
/// Hidden entirely for signed-out users or when the API returns nothing.
class TrendingShopsSection extends StatefulWidget {
  const TrendingShopsSection({super.key});

  @override
  State<TrendingShopsSection> createState() => _TrendingShopsSectionState();
}

class _TrendingShopsSectionState extends State<TrendingShopsSection> {
  late Future<List<Restaurant>> _future;
  final Map<String, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Restaurant>> _load() async {
    if (!AuthService().isLoggedIn) return [];
    try {
      // Shop list is global; coordinates are only used for distance labels.
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();
      return await RestaurantRepository.instance
          .getTrendingShops(lat: coords.lat, lon: coords.lon, size: 10)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return [];
    }
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus =
        !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
    setState(() => _localFavorites[restaurant.id] = newStatus);
    try {
      await RestaurantRepository.instance.toggleShopFavorite(
        int.tryParse(restaurant.id) ?? 0,
        newStatus,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _localFavorites[restaurant.id] = !newStatus);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        final shops = snapshot.data ?? [];
        if (shops.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('food.trending_now'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shops.length,
                itemBuilder: (context, index) {
                  final data = shops[index];
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
                    compact: true,
                    isFavorite: _localFavorites[data.id] ?? data.isFavorite,
                    onFavoriteToggle: () => _toggleFavorite(data),
                    width: 240,
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
            const SizedBox(height: 24),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const ImageSkeletonLoader(width: 150, height: 20),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 270,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (_, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const ImageSkeletonLoader(height: 160),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
