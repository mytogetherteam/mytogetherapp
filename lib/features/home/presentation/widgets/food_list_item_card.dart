import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'image_skeleton_loader.dart';
import '../../../../core/utils/price_formatter.dart';
import 'shop_item_metadata_row.dart';

class FoodListItemCard extends StatelessWidget {
  final String title;
  final String description;
  final double price;
  final double originalPrice;
  final String currency;
  final String imagePath;
  final bool isFavorite;
  final String? displayPrice;
  final double rating;
  final int reviewCount;
  final double? distanceKm;
  final String? estimatedTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  const FoodListItemCard({
    super.key,
    required this.title,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.imagePath,
    this.currency = '฿',
    this.isFavorite = false,
    this.displayPrice,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.distanceKm,
    this.estimatedTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    this.onTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final double effectivePrice = (price == 0 && originalPrice > 0) ? originalPrice : price;
    final bool hasDiscount = originalPrice > effectivePrice;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24)
        ),
        child: Row(
          children: [
            // Image Section
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                imagePath,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: frame != null
                        ? SizedBox(width: 100, height: 100, child: child)
                        : const ImageSkeletonLoader(width: 100, height: 100),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[100],
                  child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Details Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
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
                  ShopItemMetadataRow(
                    rating: rating > 0 ? rating : null,
                    reviewCount: reviewCount,
                    distanceKm: distanceKm,
                    deliveryTime: estimatedTime,
                    deliveryFee: deliveryFee,
                    originalDeliveryFee: originalDeliveryFee,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (effectivePrice > 0 || hasDiscount || (displayPrice != null && displayPrice != '฿ 0' && displayPrice != '฿0' && displayPrice != '0')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (hasDiscount) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              originalPrice.toStringAsFixed(0).toFormattedPrice(currency: currency),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          displayPrice ?? effectivePrice.toStringAsFixed(0).toFormattedPrice(currency: currency),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFED3973),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Add Button
            if (effectivePrice > 0 || hasDiscount || (displayPrice != null && displayPrice != '฿ 0' && displayPrice != '฿0' && displayPrice != '0'))
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFED3973),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
