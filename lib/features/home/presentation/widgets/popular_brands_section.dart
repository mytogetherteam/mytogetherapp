import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'view_all_icon_button.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;

class PopularBrandsSection extends StatefulWidget {
  const PopularBrandsSection({super.key});

  @override
  State<PopularBrandsSection> createState() => _PopularBrandsSectionState();
}

class _PopularBrandsSectionState extends State<PopularBrandsSection> {
  Future<List<Restaurant>>? _brandsFuture;

  @override
  void initState() {
    super.initState();
    _brandsFuture = RestaurantRepository.instance.getPopularShops();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFFEF0F5), // Base light pink
      ),
      child: Stack(
        children: [
          // Background Decorative Shapes
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
                        'Popular Restaurants',
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
                // Horizontal scrolling list of columns
                SizedBox(
                  height: 300,
                  child: FutureBuilder<List<Restaurant>>(
                    future: _brandsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return _buildSkeleton();
                      }

                      final brands = snapshot.data ?? [];
                      if (brands.isEmpty) return const SizedBox.shrink();

                      // Group brands into chunks of 3 for the horizontal scroll
                      final List<List<Restaurant>> chunks = [];
                      for (var i = 0; i < brands.length; i += 3) {
                        chunks.add(brands.sublist(i, i + 3 > brands.length ? brands.length : i + 3));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: chunks.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final chunk = chunks[index];
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
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) => Column(
        children: List.generate(3, (i) => Padding(
          padding: EdgeInsets.only(bottom: i < 2 ? 12 : 0),
          child: Container(
            width: 250,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        )),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final Restaurant brand;
  const _BrandCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 88,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rounded Logo Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade100, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                brand.imagePath.isNotEmpty ? brand.imagePath : 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=100&h=100&fit=crop',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.store_rounded, color: Colors.grey.shade400, size: 28),
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      brand.rating.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' · ${brand.deliveryTime} · ${brand.distance}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
