import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'image_skeleton_loader.dart';
import '../../../../core/utils/price_formatter.dart';
import 'shop_item_metadata_row.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';

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
  final String? id;
  final bool isAvailable;
  final String publishStatus;

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
    this.id,
    this.isAvailable = true,
    this.publishStatus = 'PUBLISHED',
  });

  @override
  Widget build(BuildContext context) {
    final double effectivePrice = (price == 0 && originalPrice > 0) ? originalPrice : price;
    final bool hasDiscount = originalPrice > effectivePrice;

    final bool effectiveIsHidden = (publishStatus == 'UNPUBLISHED' || publishStatus == 'ARCHIVED');
    final bool effectiveIsDisabled = !effectiveIsHidden && !isAvailable;

    if (effectiveIsHidden) return const SizedBox.shrink();

    return _OutOfStockListWrapper(
      isDisabled: effectiveIsDisabled,
      child: GestureDetector(
        onTap: effectiveIsDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
                          onTap: onFavoriteToggle ??
                              () => AppDialog.showUnavailable(context),
                          child: Icon(
                            isFavorite ? PhosphorIcons.heartFill : PhosphorIcons.heart,
                            color: isFavorite ? AppColors.primary : Colors.grey[400],
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
                      showDeliveryFee: false,
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
                    if (effectivePrice > 0 ||
                        hasDiscount ||
                        (displayPrice != null && displayPrice != '฿ 0' && displayPrice != '฿0' && displayPrice != '0')) ...[
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
                          GradientText(
                            displayPrice ?? effectivePrice.toStringAsFixed(0).toFormattedPrice(currency: currency),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Add Button
              if (effectivePrice > 0 ||
                  hasDiscount ||
                  (displayPrice != null && displayPrice != '฿ 0' && displayPrice != '฿0' && displayPrice != '0'))
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
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
      ),
    );
  }
}

class _OutOfStockListWrapper extends StatelessWidget {
  final bool isDisabled;
  final Widget child;

  const _OutOfStockListWrapper({required this.isDisabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isDisabled) return child;
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: Opacity(opacity: 0.6, child: child),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Out of Stock',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
