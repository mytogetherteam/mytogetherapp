import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'image_skeleton_loader.dart';
import '../../../../core/utils/price_formatter.dart';
import 'shop_item_metadata_row.dart';
import '../../../../core/presentation/widgets/menu_image_placeholder.dart';
import 'order_unavailability_ui.dart';
import '../../data/models/shop_dto.dart' show OperatingHourDto;
import '../../data/restaurant_order_availability.dart';
import '../../data/shop_order_state_cache.dart';

class FoodListItemCard extends StatelessWidget {
  final String title;
  final String description;
  final double price;
  final double originalPrice;
  final String currency;
  final String imagePath;
  final String? displayPrice;
  final double rating;
  final int reviewCount;
  final double? distanceKm;
  final String? estimatedTime;
  final String? deliveryFee;
  final String? originalDeliveryFee;
  final VoidCallback? onTap;
  final String? id;
  final bool isAvailable;
  final String publishStatus;
  final String restaurantId;
  final bool deliveryEnabled;
  final List<OperatingHourDto> operatingHours;
  final String restaurantStatus;
  final RestaurantOrderAvailability? orderAvailability;

  const FoodListItemCard({
    super.key,
    required this.title,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.imagePath,
    required this.restaurantId,
    this.currency = '฿',
    this.displayPrice,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.distanceKm,
    this.estimatedTime,
    this.deliveryFee,
    this.originalDeliveryFee,
    this.onTap,
    this.id,
    this.isAvailable = true,
    this.publishStatus = 'PUBLISHED',
    this.deliveryEnabled = true,
    this.operatingHours = const [],
    this.restaurantStatus = 'Open',
    this.orderAvailability,
  });

  @override
  Widget build(BuildContext context) {
    ShopOrderStateCache.instance.ensureListening();

    final double effectivePrice = (price == 0 && originalPrice > 0) ? originalPrice : price;
    final bool hasDiscount = originalPrice > effectivePrice;

    final bool effectiveIsHidden = (publishStatus == 'UNPUBLISHED' || publishStatus == 'ARCHIVED');
    final bool effectiveIsDisabled = !effectiveIsHidden && !isAvailable;

    if (effectiveIsHidden) return const SizedBox.shrink();

    final bool isAsset = imagePath.startsWith('assets/');
    final bool isNetworkImage = !isAsset && imagePath.trim().isNotEmpty;
    
    String networkUrl = imagePath;
    if (isNetworkImage && !networkUrl.startsWith('http')) {
      networkUrl = '${ApiClient.baseUrl}/${networkUrl.startsWith('/') ? networkUrl.substring(1) : networkUrl}';
    }

    return ListenableBuilder(
      listenable: ShopOrderStateCache.instance,
      builder: (context, _) {
        final shopId = int.tryParse(restaurantId) ?? 0;
        final availability = orderAvailability ??
            (shopId > 0
                ? ShopOrderStateCache.instance.availabilityForShopIdOrDefault(
                    shopId,
                    deliveryEnabled: deliveryEnabled,
                    operatingHours: operatingHours,
                    status: restaurantStatus,
                  )
                : RestaurantOrderAvailability.fromParts(
                    deliveryEnabled: deliveryEnabled,
                    operatingHours: operatingHours,
                    status: restaurantStatus,
                  ));
        final bool orderBlocked = availability.isBlocked;
        final showBadge = orderBlocked && !effectiveIsDisabled;
        final shouldDimImage = showBadge && availability.shouldDimImage;
        final hintLine = showBadge ? availability.menuCardHintLine(context) : '';

        return _OutOfStockListWrapper(
          isDisabled: effectiveIsDisabled,
          orderBlocked: orderBlocked && !effectiveIsDisabled,
          child: GestureDetector(
            onTap: effectiveIsDisabled ? null : onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Image Section
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        UnavailableImageDim(
                          active: shouldDimImage,
                          child: (!isNetworkImage && !isAsset)
                              ? SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: MenuImagePlaceholder(title: title),
                                )
                              : (isAsset
                                  ? Image.asset(
                                      imagePath,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: MenuImagePlaceholder(title: title),
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: networkUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const ImageSkeletonLoader(width: 80, height: 80),
                                      errorWidget: (context, url, error) => SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: MenuImagePlaceholder(title: title),
                                      ),
                                      fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                      memCacheWidth: 240,
                                    )),
                        ),
                        if (showBadge)
                          Positioned(
                            left: 4,
                            bottom: 4,
                            child: OrderStatusImageBadge(
                              reason: availability.reason,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        OrderBlockedMenuHint(
                          text: hintLine,
                          reason: availability.reason,
                        ),
                        if (hintLine.isEmpty) const SizedBox(height: 4),
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
      },
    );
  }
}

class _OutOfStockListWrapper extends StatelessWidget {
  final bool isDisabled;
  final bool orderBlocked;
  final Widget child;

  const _OutOfStockListWrapper({
    required this.isDisabled,
    this.orderBlocked = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDisabled && !orderBlocked) return child;
    if (orderBlocked && !isDisabled) {
      return Stack(
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0,      0,      0,      1, 0,
            ]),
            child: Opacity(opacity: 0.5, child: child),
          ),
        ],
      );
    }
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
                context.tr('common.out_of_stock'),
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



