import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'view_all_icon_button.dart';
import '../screens/restaurant_nearby_list_page.dart';
import '../screens/restaurant_detail_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../../../../core/location/location_service.dart';
import 'image_skeleton_loader.dart';

class PopularBrandsSection extends StatefulWidget {
  /// Optional header override. Defaults to `home.popular_restaurants`.
  final String? title;

  const PopularBrandsSection({super.key, this.title});

  @override
  State<PopularBrandsSection> createState() => _PopularBrandsSectionState();
}

class _PopularBrandsSectionState extends State<PopularBrandsSection> {
  Future<List<Restaurant>>? _restaurantsFuture;

  @override
  void initState() {
    super.initState();
    _restaurantsFuture = _loadPopularBrands();
  }

  Future<List<Restaurant>> _loadPopularBrands() async {
    try {
      final activeLoc = UserLocationRepository.instance.activeLocation;
      final pos = await LocationService().getCurrentPosition();

      return await RestaurantRepository.instance
          .getPopularShops(
            lat: activeLoc?.latitude ?? pos.latitude,
            lon: activeLoc?.longitude ?? pos.longitude,
            size: 10,
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('PopularBrandsSection: API error: $e');
      return [];
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

        final List<Restaurant> brands = (snapshot.data ?? []).take(10).toList();
        if (brands.isEmpty) return const SizedBox.shrink();

        // Group brands into chunks of 3 for the horizontal scroll
        final List<List<Restaurant>> brandChunks = [];
        for (var i = 0; i < brands.length; i += 3) {
          brandChunks.add(
            brands.sublist(i, i + 3 > brands.length ? brands.length : i + 3),
          );
        }

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFFEF0F5), // Base light pink
          ),
          child: Stack(
            children: [
              // Background Decorative Shape (White Curve)
              Positioned(
                right: -150,
                bottom: -50,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.title ??
                                context.tr('home.popular_restaurants'),
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
                                  builder: (context) =>
                                      const RestaurantNearbyListPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Horizontal scrolling list of columns
                    SizedBox(
                      height: 224, // Optimized height for 3 rows + spacing
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            brandChunks.length + 1, // +1 for the "More" button
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          if (index == brandChunks.length) {
                            return const _MoreCard();
                          }
                          final chunk = brandChunks[index];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _BrandCard(brand: chunk[0]),
                              if (chunk.length > 1) ...[
                                const SizedBox(height: 12),
                                _BrandCard(brand: chunk[1]),
                              ],
                              if (chunk.length > 2) ...[
                                const SizedBox(height: 12),
                                _BrandCard(brand: chunk[2]),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF0F5),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title ?? context.tr('home.popular_restaurants'),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 224,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _shimmerCard(),
                  const SizedBox(height: 12),
                  _shimmerCard(),
                  const SizedBox(height: 12),
                  _shimmerCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerCard() {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const ImageSkeletonLoader(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const ImageSkeletonLoader(width: 100, height: 14),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const ImageSkeletonLoader(width: 60, height: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RestaurantNearbyListPage(),
            ),
          );
        },
        child: Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.caretRightBold,
                color: Colors.black87,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('common.more'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final Restaurant brand;

  const _BrandCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantDetailPage(
              id: brand.id,
              name: brand.name,
              category: brand.category,
              rating: brand.rating,
              distance: brand.distance,
              imagePath: brand.imagePath,
              logoPath: brand.logoPath,
              deliveryTime: brand.deliveryTime,
              status: brand.status,
              isFavorite: brand.isFavorite,
            ),
          ),
        );
      },
      child: Container(
        width: 210, // Fixed width for consistent columns
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Rounded Logo Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade100, width: 1),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  brand.logoPath.isNotEmpty ? brand.logoPath : brand.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.store_rounded,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    brand.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        brand.rating.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ' · ${brand.deliveryTime} · ${brand.distance}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
