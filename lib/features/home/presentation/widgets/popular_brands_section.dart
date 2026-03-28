import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'view_all_icon_button.dart';
import '../../data/fallback_data.dart';

class PopularBrandsSection extends StatelessWidget {
  const PopularBrandsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Use high-quality fallback data
    final List<Map<String, dynamic>> brands = FallbackData.popularBrands;

    // Group brands into chunks of 3 for the horizontal scroll
    final List<List<Map<String, dynamic>>> brandChunks = [];
    for (var i = 0; i < brands.length; i += 3) {
      brandChunks.add(brands.sublist(i, i + 3 > brands.length ? brands.length : i + 3));
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
                  height: 224, // Optimized height for 3 rows + spacing
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: brandChunks.length + 1, // +1 for the "More" button
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
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
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
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
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              color: Colors.black87,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              'More',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final Map<String, dynamic> brand;

  const _BrandCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                brand['logoUrl'],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.store_rounded, color: Colors.grey.shade400, size: 24),
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
                  brand['name'],
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
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      brand['rating'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' · ${brand['time']} · ${brand['distance']}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
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
