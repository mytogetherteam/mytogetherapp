import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'view_all_icon_button.dart';
import 'image_skeleton_loader.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/menu_item_dto.dart';

class TogetherDealsSection extends StatefulWidget {
  const TogetherDealsSection({super.key});

  @override
  State<TogetherDealsSection> createState() => _TogetherDealsSectionState();
}

class _TogetherDealsSectionState extends State<TogetherDealsSection> {
  Future<List<MenuItemDto>>? _dealsFuture;

  @override
  void initState() {
    super.initState();
    _dealsFuture = RestaurantRepository.instance.getTogetherDeals();
  }

  @override
  Widget build(BuildContext context) {
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
          height: 220,
          child: FutureBuilder<List<MenuItemDto>>(
            future: _dealsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return _buildSkeleton();
              }

              final deals = snapshot.data ?? [];
              if (deals.isEmpty) return const SizedBox.shrink();

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 20),
                itemCount: deals.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _DealCard(item: deals[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20, right: 20),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: const ImageSkeletonLoader(width: 130, height: 120),
            ),
            const SizedBox(height: 8),
            Container(width: 60, height: 14, color: Colors.grey[200]),
            const SizedBox(height: 4),
            Container(width: 100, height: 14, color: Colors.grey[200]),
          ],
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final MenuItemDto item;
  const _DealCard({required this.item});

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
              imageUrl: item.imagePath,
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
                '฿${item.price.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFED3973),
                ),
              ),
              if (item.originalPrice != null) ...[
                const SizedBox(width: 5),
                Text(
                  '฿${item.originalPrice!.toInt()}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          // Food name
          Text(
            item.title,
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
              Icon(PhosphorIcons.bicycle(), size: 12, color: const Color(0xFF00A560)),
              const SizedBox(width: 3),
              Text(
                '${item.deliveryFee ?? '฿30'} · ${item.estimatedTime ?? '20'} min',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

