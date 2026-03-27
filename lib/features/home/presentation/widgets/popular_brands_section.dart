import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'view_all_icon_button.dart';

class PopularBrandsSection extends StatelessWidget {
  const PopularBrandsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> brands = [
      {
        'name': 'YKKO',
        'rating': '4.7',
        'time': '40min',
        'distance': '2.0km',
        'logoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSx-D7wYn9S1_0N3WzS-Yk8yV_zXp9z_GgD9g&s',
      },
      {
        'name': 'Sushi Place',
        'rating': '4.7',
        'time': '40min',
        'distance': '2.0km',
        'logoUrl': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=100&q=80',
      },
      {
        'name': 'Shwe Tea House',
        'rating': '4.7',
        'time': '40min',
        'distance': '2.0km',
        'logoUrl': 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=100&q=80',
      },
      {
        'name': 'KFC',
        'rating': '4.5',
        'time': '25min',
        'distance': '1.5km',
        'logoUrl': 'https://images_production.sgp1.digitaloceanspaces.com/logo/kfc_logo.png',
      },
      {
        'name': 'Burger King',
        'rating': '4.3',
        'time': '30min',
        'distance': '1.8km',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Burger_King_logo_%282021%29.svg/1024px-Burger_King_logo_%282021%29.svg.png',
      },
      {
        'name': "McDonald's",
        'rating': '4.2',
        'time': '20min',
        'distance': '1.2km',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/McDonald%27s_Golden_Arches.svg/1200px-McDonald%27s_Golden_Arches.svg.png',
      },
      {
        'name': 'Pizza Hut',
        'rating': '4.4',
        'time': '35min',
        'distance': '2.2km',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d2/Pizza_Hut_logo.svg/1200px-Pizza_Hut_logo.svg.png',
      },
      {
        'name': 'Starbucks',
        'rating': '4.8',
        'time': '15min',
        'distance': '0.5km',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d3/Starbucks_Corporation_Logo_2011.svg/1200px-Starbucks_Corporation_Logo_2011.svg.png',
      },
      {
        'name': 'The Pizza Company',
        'rating': '4.6',
        'time': '45min',
        'distance': '3.0km',
        'logoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR6_GZ-8v7z-qf9v1XzVz-fXvXw-y9fXvXw-g&s',
      },
    ];

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
