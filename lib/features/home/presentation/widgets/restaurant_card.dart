import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'image_skeleton_loader.dart';
import 'shop_item_metadata_row.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final String distance; // the formatted distance
  final String? deliveryTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final String imagePath;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.category,
    required this.rating,
    this.reviewCount = 0,
    required this.distance,
    this.deliveryTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    required this.imagePath,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onTap,
    this.width,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 240,
        margin: margin ?? const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Favorite Button
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: imagePath.trim().isEmpty
                    ? _buildFallbackImage()
                    : CachedNetworkImage(
                        imageUrl: imagePath,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const ImageSkeletonLoader(
                          height: 160,
                        ),
                        errorWidget: (context, url, error) => _buildFallbackImage(),
                        fadeInDuration: const Duration(milliseconds: 300),
                      ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => AppDialog.showUnavailable(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? PhosphorIcons.heartFill : PhosphorIcons.heart,
                      color: isFavorite ? AppColors.primary : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Text Info Section with Padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Restaurant Name
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Metadata Row
                Transform.translate(
                  offset: const Offset(-1.5, 0),
                  child: ShopItemMetadataRow(
                    rating: rating > 0 ? rating : null,
                    reviewCount: reviewCount,
                    // Since distance is a string here ('5.0 km'), we will just parse it
                    distanceKm: double.tryParse(distance.replaceAll(RegExp(r'[^0-9.]'), '')),
                    deliveryTime: deliveryTime,
                    deliveryFee: deliveryFee,
                    originalDeliveryFee: originalDeliveryFee,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 32),
            const SizedBox(height: 4),
            Text(
              'No Image',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
