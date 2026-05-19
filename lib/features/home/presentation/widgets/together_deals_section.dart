import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/presentation/widgets/web_safe_image/web_safe_image.dart';
import 'view_all_icon_button.dart';
import 'image_skeleton_loader.dart';
import '../../../../core/presentation/widgets/gradient_text.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../../../core/location/location_service.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/restaurant_detail_page.dart';
import '../../../../core/utils/price_formatter.dart';

class TogetherDealsSection extends StatefulWidget {
  const TogetherDealsSection({super.key});

  @override
  State<TogetherDealsSection> createState() => _TogetherDealsSectionState();
}

class _TogetherDealsSectionState extends State<TogetherDealsSection> {
  Future<ShopFeedSectionDto>? _dealsFuture;

  @override
  void initState() {
    super.initState();
    _dealsFuture = _loadDeals();
  }

  Future<ShopFeedSectionDto> _loadDeals() async {
    try {
      final activeLoc = UserLocationRepository.instance.activeLocation;
      // Use cached GPS position or default — never block on a fresh GPS request.
      // On PWA, getCurrentPosition() can trigger a browser permission dialog
      // and hang for several seconds, blocking the entire deals section.
      final pos = LocationService().cachedPosition;
      final lat = activeLoc?.latitude ?? pos?.latitude ?? LocationService.defaultLat;
      final lon = activeLoc?.longitude ?? pos?.longitude ?? LocationService.defaultLon;
      
      return await RestaurantRepository.instance.getFoodTabFeed(
        feedType: 'hot-deals',
        lat: lat,
        lon: lon,
        size: 10,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('TogetherDealsSection: API error: $e');
      return ShopFeedSectionDto(items: []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopFeedSectionDto>(
      future: _dealsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }

        final deals = (snapshot.data?.items ?? []).take(10).toList();
        if (deals.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Together ',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GradientText(
                            'Up to 40% Off ',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Text(
                            '✦',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ViewAllIconButton(
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Horizontal scroll cards
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 20),
                itemCount: deals.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _DealCard(deal: deals[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Together Deals',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 20),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: const ImageSkeletonLoader(width: 130, height: 120, showLogo: true),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 60, height: 14),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 100, height: 12),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ImageSkeletonLoader(width: 80, height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DealCard extends StatelessWidget {
  final ShopFeedItemDto deal;
  const _DealCard({required this.deal});

  @override
  Widget build(BuildContext context) {
    final double effectivePrice = (deal.price == 0 && deal.originalPrice != null && deal.originalPrice! > 0)
        ? deal.originalPrice!
        : deal.price;
    final bool hasDiscount = deal.originalPrice != null && deal.originalPrice! > effectivePrice;
    
    final bool showPrice = effectivePrice > 0 || 
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
              child: SizedBox(
                width: 130,
                height: 120,
                child: WebSafeImage(
                  imageUrl: deal.imageUrl ?? '',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Price row
            if (showPrice)
              Row(
                children: [
                  GradientText(
                    deal.displayPrice ?? effectivePrice.toStringAsFixed(0).toFormattedPrice(currency: deal.currency),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (hasDiscount)
                    Text(
                      deal.originalPrice!.toStringAsFixed(0).toFormattedPrice(currency: deal.currency),
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
            // Delivery info
            Row(
              children: [
                Icon(PhosphorIcons.bicycle(), size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    '${deal.deliveryFee?.toFormattedPrice(currency: deal.currency) ?? 'Free'} · ${deal.estimatedTime ?? '20-30 min'}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
