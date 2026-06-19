import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/collection_dto.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../widgets/food_menu_item_card.dart';

/// Shows a single curated collection and its menu items.
/// Backed by `GET /api/user/collections/:id`.
class CollectionDetailPage extends StatefulWidget {
  final int collectionId;
  final String collectionName;

  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late Future<CollectionDto?> _future;
  final Map<int, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _future = RestaurantRepository.instance.getCollectionById(widget.collectionId);
  }

  Future<void> _toggleFavorite(ShopFeedItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    setState(() => _localFavorites[item.id] = newStatus);
    try {
      await RestaurantRepository.instance.toggleMenuFavorite(item.id, newStatus);
    } catch (_) {
      if (mounted) setState(() => _localFavorites[item.id] = !newStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.collectionName,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<CollectionDto?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final collection = snapshot.data;
          final items = collection?.items ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                context.tr('collection.empty'),
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              if (collection?.description != null &&
                  collection!.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      collection.description!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = items[i];
                      return FoodMenuItemCard(
                        id: item.id.toString(),
                        restaurantId: item.shopId.toString(),
                        title: item.name,
                        price: item.price,
                        currency: item.currency,
                        imagePath: item.imageUrl ?? '',
                        restaurantName: item.shopName,
                        isFavorite:
                            _localFavorites[item.id] ?? item.isFavorite,
                        rating: item.rating,
                        reviewCount: item.reviewCount,
                        distanceKm: item.distanceKm,
                        estimatedTime: item.estimatedTime,
                        deliveryFee: item.deliveryFee,
                        originalDeliveryFee: item.originalDeliveryFee,
                        originalPrice: item.originalPrice,
                        displayPrice: item.displayPrice,
                        onFavoriteToggle: () => _toggleFavorite(item),
                        forceRestaurantNavigation: true,
                        isAvailable: item.isAvailable,
                        publishStatus: item.publishStatus,
                        deliveryEnabled: item.deliveryEnabled,
                        operatingHours: item.operatingHours,
                        restaurantStatus: item.restaurantStatus,
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
