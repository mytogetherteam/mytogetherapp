import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/presentation/widgets/primary_gradient_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'image_skeleton_loader.dart';
import 'shop_item_metadata_row.dart';

class NearbyRestaurantListItem extends StatelessWidget {
  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final String distance;
  final String imagePath;
  final String deliveryTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final String status;
  final List<String> imageUrls;
  final bool isExpanded;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onViewMenu;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDirectionTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onShareTap;

  const NearbyRestaurantListItem({
    super.key,
    required this.name,
    required this.category,
    required this.rating,
    this.reviewCount = 0,
    required this.distance,
    required this.imagePath,
    required this.deliveryTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    required this.status,
    this.imageUrls = const <String>[],
    this.isExpanded = false,
    this.isFavorite = false,
    this.onTap,
    this.onViewMenu,
    this.onFavoriteToggle,
    this.onDirectionTap,
    this.onCallTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAsset = imagePath.startsWith('assets/');
    final bool isNetworkImage = !isAsset && imagePath.trim().isNotEmpty;
    
    String networkUrl = imagePath;
    if (isNetworkImage && !networkUrl.startsWith('http')) {
      networkUrl = '${ApiClient.baseUrl}/${networkUrl.startsWith('/') ? networkUrl.substring(1) : networkUrl}';
    }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: (!isNetworkImage && !isAsset)
                      ? Container(
                          height: 80,
                          width: 80,
                          color: Colors.grey[200],
                          child: Icon(PhosphorIcons.image, color: Colors.grey),
                        )
                      : (isAsset
                          ? Image.asset(
                              imagePath,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 80,
                                width: 80,
                                color: Colors.grey[200],
                                child: Icon(PhosphorIcons.image, color: Colors.grey),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: networkUrl,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const ImageSkeletonLoader(height: 80, width: 80),
                              errorWidget: (context, url, error) => Container(
                                height: 80,
                                width: 80,
                                color: Colors.grey[200],
                                child: Icon(PhosphorIcons.image, color: Colors.grey),
                              ),
                              fadeInDuration: const Duration(milliseconds: 300),
                            )),
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
                              isFavorite ? PhosphorIcons.heartFill : PhosphorIcons.heart,
                              color: isFavorite ? AppColors.primary : Colors.grey[400],
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
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.localizedStatus(status),
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
                      const SizedBox(height: 4),
                      ShopItemMetadataRow(
                        rating: rating > 0 ? rating : null,
                        reviewCount: reviewCount,
                        distanceKm: double.tryParse(distance.replaceAll(RegExp(r'[^0-9.]'), '')),
                        deliveryTime: deliveryTime,
                        deliveryFee: deliveryFee,
                        originalDeliveryFee: originalDeliveryFee,
                      ),
                      const SizedBox(height: 8),
                      // Action Buttons Row
                      Row(
                        children: [
                          if (onDirectionTap != null) ...[
                            GestureDetector(
                              onTap: onDirectionTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GradientText(
                                      context.tr('home.direction'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.near_me_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (onCallTap != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onCallTap,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.phone,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                          if (onShareTap != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onShareTap,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.shareNetwork,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
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
              PrimaryGradientButton(
                onPressed: onViewMenu,
                height: 48,
                child: Text(
                  context.tr('home.view_menu'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
