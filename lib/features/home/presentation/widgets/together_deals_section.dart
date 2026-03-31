import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'view_all_icon_button.dart';
import 'image_skeleton_loader.dart';
import '../../data/fallback_data.dart';
import '../screens/together_deals_detail_page.dart';

class TogetherDealsSection extends StatelessWidget {
  const TogetherDealsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Use high-quality fallback data
    final deals = FallbackData.togetherDeals.map((data) => _Deal(
      imagePath: data['imagePath']!,
      price: data['price'],
      originalPrice: data['originalPrice'],
      name: data['name']!,
      deliveryFee: data['deliveryFee'],
      minutes: data['minutes'],
    )).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TogetherDealsDetailPage(),
                ),
              );
            },
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TogetherDealsDetailPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
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
  }
}

class _Deal {
  final String imagePath;
  final int price;
  final int originalPrice;
  final String name;
  final int deliveryFee;
  final int minutes;

  const _Deal({
    required this.imagePath,
    required this.price,
    required this.originalPrice,
    required this.name,
    required this.deliveryFee,
    required this.minutes,
  });
}

class _DealCard extends StatelessWidget {
  final _Deal deal;
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
              imageUrl: deal.imagePath,
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
                '฿${deal.price}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFED3973),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '฿${deal.originalPrice}',
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
              Text(
                '฿${deal.deliveryFee} · ${deal.minutes}min',
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
