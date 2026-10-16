import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/location/location_refresh_mixin.dart';
import 'package:mytogetherapp/features/food/data/order_again.dart';
import 'package:mytogetherapp/features/home/data/restaurant_data.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_detail_page.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/restaurant_card.dart';

/// Full list behind the Order Again arrow.
class OrderAgainListPage extends StatefulWidget {
  const OrderAgainListPage({super.key});

  @override
  State<OrderAgainListPage> createState() => _OrderAgainListPageState();
}

class _OrderAgainListPageState extends State<OrderAgainListPage>
    with LocationRefreshMixin {
  Future<List<Restaurant>>? _future;

  @override
  void initState() {
    super.initState();
    _future = loadOrderAgainRestaurants(maxShops: 30);
  }

  @override
  void onActiveLocationChanged() {
    setState(() => _future = loadOrderAgainRestaurants(maxShops: 30));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.tr('food.order_again'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: FutureBuilder<List<Restaurant>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final shops = snapshot.data ?? const <Restaurant>[];
          if (shops.isEmpty) {
            return Center(
              child: Text(
                context.tr('restaurant.no_restaurants'),
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              6,
              8,
              6,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
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
                isFavorite: data.isFavorite,
                onFavoriteToggle: () {},
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
                onTap: () {
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
                },
              );
            },
          );
        },
      ),
    );
  }
}
