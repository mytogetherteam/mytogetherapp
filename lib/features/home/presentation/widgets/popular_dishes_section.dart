import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'food_menu_item_card.dart';
import 'view_all_icon_button.dart';

class PopularDishesSection extends StatelessWidget {
  final List<Map<String, dynamic>> dishes;

  const PopularDishesSection({
    super.key,
    required this.dishes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Dishes',
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            padding: EdgeInsets.only(top: 10),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.77,
            ),
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              return FoodMenuItemCard(
                id: dish['id']?.toString() ?? '0',
                restaurantId: dish['restaurantId']?.toString() ?? '0',
                title: dish['title']?.toString() ?? '',
                price: (dish['price'] as num?)?.toDouble() ?? 0.0,
                currency: dish['currency']?.toString() ?? '฿',
                imagePath: dish['imagePath']?.toString() ?? '',
                restaurantName: dish['restaurantName']?.toString() ?? '',
                rating: (dish['rating'] as num?)?.toDouble() ?? 0.0,
                reviewCount: (dish['reviewCount'] as num?)?.toInt() ?? (dish['ratingCount'] as num?)?.toInt() ?? 0,
                distanceKm: (dish['distanceKm'] as num?)?.toDouble(),
                estimatedTime: dish['estimatedTime']?.toString(),
                deliveryFee: dish['deliveryFee']?.toString(),
                originalDeliveryFee: dish['originalDeliveryFee']?.toString(),
                originalPrice: (dish['originalPrice'] as num?)?.toDouble(),
                displayPrice: dish['displayPrice']?.toString(),
                forceRestaurantNavigation: true,
              );
            },
          ),
        ),
      ],
    );
  }
}
