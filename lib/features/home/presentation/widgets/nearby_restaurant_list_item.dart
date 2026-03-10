import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_skeleton_loader.dart';


class NearbyRestaurantListItem extends StatelessWidget {
  final String name;
  final String category;
  final double rating;
  final String distance;
  final String imagePath;
  final String deliveryTime;
  final String status;
  final List<String> imageUrls;
  final bool isExpanded;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onViewMenu;
  final VoidCallback? onFavoriteToggle;

  const NearbyRestaurantListItem({
    super.key,
    required this.name,
    required this.category,
    required this.rating,
    required this.distance,
    required this.imagePath,
    required this.deliveryTime,
    required this.status,
    this.imageUrls = const <String>[],
    this.isExpanded = false,
    this.isFavorite = false,
    this.onTap,
    this.onViewMenu,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imagePath,
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ImageSkeletonLoader(height: 80, width: 80),
                    errorWidget: (context, url, error) => Container(
                      height: 80,
                      width: 80,
                      color: Colors.grey[200],
                      child: Icon(PhosphorIcons.image(), color: Colors.grey),
                    ),
                    fadeInDuration: const Duration(milliseconds: 300),
                  ),
                ),

                const SizedBox(width: 16),
                // Middle: Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: onFavoriteToggle,
                            child: Icon(
                              isFavorite ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                              color: isFavorite ? const Color(0xFFED3A72) : Colors.grey[400],
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Text('•', style: TextStyle(color: Colors.grey[400])),
                          ),
                          Text(
                            rating.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 14, color: Colors.amber),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(PhosphorIcons.car(), size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Text('•', style: TextStyle(color: Colors.grey[400])),
                          ),
                          Icon(PhosphorIcons.clock(), size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            deliveryTime,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Text('•', style: TextStyle(color: Colors.grey[400])),
                          ),
                          Text(
                            status,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: status.toLowerCase() == 'open now' || status.toLowerCase() == 'open'
                                  ? const Color(0xFF10B981)
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              if (imageUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: CachedNetworkImage(
                            imageUrl: imageUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ImageSkeletonLoader(),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              ),
                            ),
                            fadeInDuration: const Duration(milliseconds: 300),
                          ),
                        ),

                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onViewMenu,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFED3973),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'View Menu',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
