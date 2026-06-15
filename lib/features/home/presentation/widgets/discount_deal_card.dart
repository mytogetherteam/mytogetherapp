import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../screens/restaurant_detail_page.dart';
import 'image_skeleton_loader.dart';

/// Horizontal card used by the home discount carousel and the food-tab deals
/// strip. Renders a discounted [ShopFeedItemDto] (image, price, name, ETA).
class DiscountDealCard extends StatelessWidget {
  final ShopFeedItemDto deal;

  const DiscountDealCard({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    final double effectivePrice =
        (deal.price == 0 &&
            deal.originalPrice != null &&
            deal.originalPrice! > 0)
        ? deal.originalPrice!
        : deal.price;
    final bool hasDiscount =
        deal.originalPrice != null && deal.originalPrice! > effectivePrice;

    final bool showPrice =
        effectivePrice > 0 ||
        hasDiscount ||
        (deal.displayPrice != null &&
            deal.displayPrice != '฿ 0' &&
            deal.displayPrice != '฿0' &&
            deal.displayPrice != '0');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantDetailPage(
              id: deal.shopId.toString(),
              name: deal.shopName,
              targetMenuItemId: deal.id.toString(),
            ),
          ),
        );
      },
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                imageUrl: deal.imageUrl ?? '',
                width: 130,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ImageSkeletonLoader(
                  width: 130,
                  height: 120,
                  showLogo: true,
                ),
                errorWidget: (context, url, error) => Container(
                  width: 130,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.grey.shade300,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('common.no_image'),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Price row
            if (showPrice)
              Row(
                children: [
                  GradientText(
                    deal.displayPrice ??
                        effectivePrice
                            .toStringAsFixed(0)
                            .toFormattedPrice(currency: deal.currency),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (hasDiscount)
                    Text(
                      deal.originalPrice!
                          .toStringAsFixed(0)
                          .toFormattedPrice(currency: deal.currency),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 2),
            // Food name
            Text(
              deal.name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            // Estimated time (delivery icon and fee intentionally omitted).
            Text(
              deal.estimatedTime ?? '20-30 min',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
