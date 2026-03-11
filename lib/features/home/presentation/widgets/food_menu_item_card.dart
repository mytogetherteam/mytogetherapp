import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/utils/price_formatter.dart';

import 'image_skeleton_loader.dart';
import '../screens/menu_detail_page.dart';
import '../screens/restaurant_detail_page.dart';

class FoodMenuItemCard extends StatelessWidget {
  final String id;
  final String restaurantId;
  final String title;
  final double price;
  final String currency;
  final String imagePath;
  final String restaurantName;
  final bool isFavorite;
  final double rating;
  final double? originalPrice;
  final String? displayPrice;
  final bool showRestaurantName;
  final VoidCallback? onFavoriteToggle;

  const FoodMenuItemCard({
    super.key,
    required this.id,
    required this.restaurantId,
    required this.title,
    required this.price,
    required this.currency,
    required this.imagePath,
    required this.restaurantName,
    this.isFavorite = false,
    this.rating = 0.0,
    this.originalPrice,
    this.displayPrice,
    this.showRestaurantName = true,
    this.onFavoriteToggle,
    this.isHighlighted = false,
    this.forceRestaurantNavigation = false,
    this.targetMenuItemId,
  });

  final bool isHighlighted;
  final bool forceRestaurantNavigation;
  final String? targetMenuItemId;

  @override
  Widget build(BuildContext context) {
    final bool isNetworkImage = imagePath.startsWith('http');
    final bool hasDiscount = originalPrice != null && originalPrice! > price;

    return GestureDetector(
      onTap: () {
        if (forceRestaurantNavigation || (targetMenuItemId != null && targetMenuItemId != id)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailPage(
                id: restaurantId,
                name: restaurantName,
                targetMenuItemId: id,
              ),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuDetailPage(
              id: id,
              restaurantId: restaurantId,
              title: title,
              price: price,
              currency: currency,
              imagePath: imagePath,
              restaurantName: restaurantName,
              displayPrice: displayPrice,
              description: '', // Will be fetched via API in MenuDetailPage
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: (imagePath.isEmpty || imagePath.trim().isEmpty)
                      ? _buildFallbackImage()
                      : (isNetworkImage
                          ? CachedNetworkImage(
                            imageUrl: imagePath,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ImageSkeletonLoader(),
                            errorWidget: (context, url, error) => _buildFallbackImage(),
                            fadeInDuration: const Duration(milliseconds: 300),
                          )
                        : Image.asset(
                            imagePath,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackImage();
                            },
                          )),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                        color: isFavorite ? const Color(0xFFED3A72) : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Text Info Section with Padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Title Section
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                    color: isHighlighted ? const Color(0xFFED3A72) : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Restaurant & Rating Row
                Row(
                  children: [
                    if (showRestaurantName && restaurantName.isNotEmpty) ...[
                      Expanded(
                        child: Text(
                          restaurantName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (rating > 0) ...[
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Price Section
                Row(
                  children: [
                    Text(
                      displayPrice ?? price.toStringAsFixed(0).toFormattedPrice(currency: currency),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFED3A72),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(width: 6),
                      Text(
                        originalPrice!.toStringAsFixed(0).toFormattedPrice(currency: currency),
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).decorateIf(
      isHighlighted,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFED3A72), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFED3A72).withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey[400],
              size: 32,
            ),
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

extension WidgetDecorator on Widget {
  Widget decorateIf(bool condition, {required BoxDecoration decoration}) {
    if (!condition) return this;
    return Container(
      decoration: decoration,
      child: this,
    );
  }
}
