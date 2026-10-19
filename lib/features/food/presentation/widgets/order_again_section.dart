import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/location/location_refresh_mixin.dart';
import 'package:mytogetherapp/features/food/data/order_again.dart';
import 'package:mytogetherapp/features/food/presentation/screens/order_again_list_page.dart';
import 'package:mytogetherapp/features/home/data/restaurant_data.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_detail_page.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/restaurant_card.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/view_all_icon_button.dart';

/// Grab-style row: restaurants the user has already ordered from.
/// The arrow opens the full list. A card opens that restaurant.
class OrderAgainSection extends StatefulWidget {
  const OrderAgainSection({super.key});

  @override
  State<OrderAgainSection> createState() => _OrderAgainSectionState();
}

class _OrderAgainSectionState extends State<OrderAgainSection>
    with LocationRefreshMixin {
  Future<List<Restaurant>>? _future;

  @override
  void initState() {
    super.initState();
    _future = loadOrderAgainRestaurants();
  }

  @override
  void onActiveLocationChanged() {
    setState(() => _future = loadOrderAgainRestaurants());
  }

  void _openRestaurant(Restaurant data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailPage(
          id: data.id,
          name: data.name,
          category: data.category,
          rating: data.rating,
          reviewCount: data.reviewCount,
          distance: data.distance,
          imagePath: data.imagePath,
          logoPath: data.logoPath,
          deliveryTime: data.deliveryTime,
          status: data.status,
          isFavorite: data.isFavorite,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _future,
      builder: (context, snapshot) {
        final shops = snapshot.data ?? const <Restaurant>[];
        if (shops.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('food.order_again'),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    ViewAllIconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrderAgainListPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 272,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final data = shops[index];
                    return RestaurantCard(
                      name: data.name,
                      category: data.category,
                      rating: data.rating,
                      reviewCount: data.reviewCount,
                      distance: data.distance,
                      imagePath: data.imagePath,
                      logoPath: data.logoPath,
                      deliveryTime: data.deliveryTime,
                      deliveryFee: data.deliveryFee,
                      originalDeliveryFee: data.originalDeliveryFee,
                      deliveryEnabled: data.deliveryEnabled,
                      operatingHours: data.operatingHours,
                      status: data.status,
                      shopId: data.id,
                      isVerified: data.isVerified,
                      compact: true,
                      isFavorite: data.isFavorite,
                      onFavoriteToggle: () {},
                      width: 240,
                      onTap: () => _openRestaurant(data),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
