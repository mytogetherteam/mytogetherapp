import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_skeleton_loader.dart';
import '../../../../core/utils/price_formatter.dart';
import 'shop_item_metadata_row.dart';

class FoodListItemCard extends StatefulWidget {
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
  State<FoodListItemCard> createState() => _FoodListItemCardState();
}

class _FoodListItemCardState extends State<FoodListItemCard> {
  @override
  Widget build(BuildContext context) {
    final bool hasInvalidImage = widget.imagePath.trim().isEmpty;

    return GestureDetector(
      onTap: widget.onTap,
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
              child: hasInvalidImage || widget.imagePath.isEmpty
                  ? _buildFallbackImage()
                  : CachedNetworkImage(
                      imageUrl: widget.imagePath,
                      width: 100,
                      height: 100,
                      memCacheWidth: 200,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (context, url) => const ImageSkeletonLoader(width: 100, height: 100),
                      errorWidget: (context, url, error) => _buildFallbackImage(),
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
                          widget.title,
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
                        onTap: widget.onFavoriteToggle,
                        child: Icon(
                          widget.isFavorite ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                          color: widget.isFavorite ? const Color(0xFFED3A72) : Colors.grey[400],
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ShopItemMetadataRow(
                    rating: widget.rating > 0 ? widget.rating : null,
                    reviewCount: widget.reviewCount,
                    distanceKm: widget.distanceKm,
                    deliveryTime: widget.estimatedTime,
                    deliveryFee: widget.deliveryFee,
                    originalDeliveryFee: widget.originalDeliveryFee,
                  ),
                  if (widget.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (widget.price > 0 || widget.originalPrice > widget.price || (widget.displayPrice != null && widget.displayPrice != '฿ 0' && widget.displayPrice != '฿0' && widget.displayPrice != '0')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.originalPrice > widget.price) ...[
                          Text(
                            widget.originalPrice.toStringAsFixed(0).toFormattedPrice(currency: widget.currency),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.displayPrice ?? widget.price.toStringAsFixed(0).toFormattedPrice(currency: widget.currency),
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
            if (widget.price > 0 || widget.originalPrice > widget.price || (widget.displayPrice != null && widget.displayPrice != '฿ 0' && widget.displayPrice != '฿0' && widget.displayPrice != '0'))
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

  Widget _buildFallbackImage() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 24),
            const SizedBox(height: 4),
            Text(
              'No Image',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
