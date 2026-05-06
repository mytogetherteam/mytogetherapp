import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'view_all_icon_button.dart';
import 'image_skeleton_loader.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../../../core/location/location_service.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';

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
      final pos = await LocationService().getCurrentPosition();
      
      return await RestaurantRepository.instance.getFoodTabFeed(
        feedType: 'hot-deals',
        lat: activeLoc?.latitude ?? pos.latitude,
        lon: activeLoc?.longitude ?? pos.longitude,
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

        final deals = snapshot.data?.items ?? [];
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
                        TextSpan(
                          text: 'Up to 40% Off ',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFED3973),
                          ),
                        ),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Text(
                            '✦',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFED3973),
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
                separatorBuilder: (_, __) => const SizedBox(width: 12),
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
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: const ImageSkeletonLoader(width: 130, height: 120),
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
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food image
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: deal.imageUrl ?? '',
              width: 130,
              height: 120,
              fit: BoxFit.cover,
              placeholder: (context, url) => const ImageSkeletonLoader(
                width: 130,
                height: 120,
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
                      'No Image',
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
          Row(
            children: [
              Text(
                '${deal.currency}${deal.price.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFED3973),
                ),
              ),
              const SizedBox(width: 5),
              if (deal.originalPrice != null)
                Text(
                  '${deal.currency}${deal.originalPrice!.toStringAsFixed(0)}',
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
                  '${deal.currency}${deal.deliveryFee ?? '0'} · ${deal.estimatedTime ?? '20-30 min'}',
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
    );
  }
}
