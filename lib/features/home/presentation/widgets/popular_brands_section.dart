import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'view_all_icon_button.dart';
import '../screens/food_collection_list_page.dart';
import '../screens/restaurant_detail_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import 'image_skeleton_loader.dart';

class PopularBrandsSection extends StatefulWidget {
  final String? title;

  const PopularBrandsSection({super.key, this.title});

  @override
  State<PopularBrandsSection> createState() => _PopularBrandsSectionState();
}

class _PopularBrandsSectionState extends State<PopularBrandsSection> {
  Future<List<Restaurant>>? _restaurantsFuture;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _restaurantsFuture = _loadPopularBrands();
  }

  Future<List<Restaurant>> _loadPopularBrands() async {
    try {
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();

      return await RestaurantRepository.instance
          .getPopularShops(
            lat: coords.lat,
            lon: coords.lon,
            size: 20, // Request up to 20 for 2 pages
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

        final List<Restaurant> brands = (snapshot.data ?? []).take(20).toList();
        if (brands.isEmpty) return const SizedBox.shrink();

        final List<List<Restaurant>> pages = [];
        for (var i = 0; i < brands.length; i += 8) {
          pages.add(brands.sublist(i, i + 8 > brands.length ? brands.length : i + 8));
        }

        return Container(
          width: double.infinity,
          color: Colors.white, // Plain background
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    ViewAllIconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FoodCollectionListPage(
                              kind: FoodCollectionKind.popular,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220, // Reduced height
                child: PageView.builder(
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, pageIndex) {
                    final pageItems = pages[pageIndex];
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.8, // Adjusted to fit 4 columns
                      ),
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        return _BrandCardSquare(brand: pageItems[index]);
                      },
                    );
                  },
                ),
              ),
              // Dots Indicator
              if (pages.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: _currentPage == index
                            ? AppColors.primaryGradient
                            : null,
                        color: _currentPage == index
                            ? null
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 0),
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
            height: 220,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: 8,
              itemBuilder: (context, index) => const _ShimmerCardSquare(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ShimmerCardSquare extends StatelessWidget {
  const _ShimmerCardSquare();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const ImageSkeletonLoader(),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _BrandCardSquare extends StatelessWidget {
  final Restaurant brand;

  const _BrandCardSquare({required this.brand});

  @override
  Widget build(BuildContext context) {
    final imageUrl = brand.logoPath.isNotEmpty ? brand.logoPath : brand.imagePath;

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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isEmpty
                  ? Icon(
                      Icons.store_rounded,
                      color: Colors.grey.shade400,
                      size: 28,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.store_rounded,
                        color: Colors.grey.shade400,
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              brand.name,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
