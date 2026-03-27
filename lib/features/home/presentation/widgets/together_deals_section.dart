import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'view_all_icon_button.dart';

class TogetherDealsSection extends StatelessWidget {
  const TogetherDealsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final deals = [
      _Deal(
        imagePath: 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=400&q=80',
        price: 65,
        originalPrice: 75,
        name: 'Spicy Tofu Salad',
        deliveryFee: 25,
        minutes: 30,
      ),
      _Deal(
        imagePath: 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=400&q=80',
        price: 45,
        originalPrice: 75,
        name: 'Avocado Toast',
        deliveryFee: 35,
        minutes: 20,
      ),
      _Deal(
        imagePath: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&q=80',
        price: 95,
        originalPrice: 120,
        name: 'Mango Sticky Ri...',
        deliveryFee: 40,
        minutes: 40,
      ),
      _Deal(
        imagePath: 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400&q=80',
        price: 115,
        originalPrice: 150,
        name: 'Pad Thai',
        deliveryFee: 30,
        minutes: 25,
      ),
      _Deal(
        imagePath: 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&q=80',
        price: 55,
        originalPrice: 80,
        name: 'Pancakes Stack',
        deliveryFee: 20,
        minutes: 15,
      ),
    ];

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
            child: Image.network(
              deal.imagePath,
              width: 130,
              height: 120,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 130,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFED3973),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: 130,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.fastfood_rounded, color: Colors.grey.shade300, size: 36),
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
