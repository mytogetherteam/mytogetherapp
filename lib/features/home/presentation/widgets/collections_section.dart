import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/models/collection_dto.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../screens/collection_detail_page.dart';
import 'food_menu_item_card.dart';
import 'image_skeleton_loader.dart';
import 'view_all_icon_button.dart';

/// Curated collections from `GET /api/user/collections`.
/// Each collection is its own section (title = collection name), with menu
/// items in a two-column grid matching other food-tab rails. Up to eight
/// items are shown; a ">" control appears when more exist.
class CollectionsSection extends StatefulWidget {
  const CollectionsSection({super.key});

  static const int previewItemLimit = 8;
  static const double betweenCollectionsSpacing = 48;

  @override
  State<CollectionsSection> createState() => _CollectionsSectionState();
}

class _CollectionsSectionState extends State<CollectionsSection> {
  late Future<List<CollectionDto>> _future;
  final Map<int, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CollectionDto>> _load() async {
    if (!AuthService().isLoggedIn) return [];
    try {
      return await RestaurantRepository.instance
          .getCollections(size: 10)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return [];
    }
  }

  void _openCollection(CollectionDto collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailPage(
          collectionId: collection.id,
          collectionName: collection.name,
        ),
      ),
    );
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

  bool _hasMoreItems(CollectionDto collection) {
    final total = collection.itemCount > collection.items.length
        ? collection.itemCount
        : collection.items.length;
    return total > CollectionsSection.previewItemLimit;
  }

  int _gridCrossAxisCount(BuildContext context) {
    return MediaQuery.of(context).size.width > 600 ? 4 : 2;
  }

  SliverGridDelegateWithFixedCrossAxisCount _gridDelegate(
    BuildContext context,
  ) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _gridCrossAxisCount(context),
      crossAxisSpacing: 16,
      mainAxisSpacing: 24,
      childAspectRatio: 0.85,
    );
  }

  Widget _buildMenuItemCard(ShopFeedItemDto item) {
    return FoodMenuItemCard(
      id: item.id.toString(),
      restaurantId: item.shopId.toString(),
      title: item.name,
      price: item.price,
      currency: item.currency,
      imagePath: item.imageUrl ?? '',
      restaurantName: item.shopName,
      isFavorite: _localFavorites[item.id] ?? item.isFavorite,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectionDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(context);
        }

        final collections = (snapshot.data ?? [])
            .where((c) => c.items.isNotEmpty)
            .toList();
        if (collections.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < collections.length; i++) ...[
              _buildCollectionBlock(context, collections[i]),
              if (i < collections.length - 1)
                const SizedBox(
                  height: CollectionsSection.betweenCollectionsSpacing,
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCollectionBlock(BuildContext context, CollectionDto collection) {
    final previewItems =
        collection.items.take(CollectionsSection.previewItemLimit).toList();
    final showViewAll = _hasMoreItems(collection);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  collection.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showViewAll)
                ViewAllIconButton(
                  onPressed: () => _openCollection(collection),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: _gridDelegate(context),
          itemCount: previewItems.length,
          itemBuilder: (context, index) =>
              _buildMenuItemCard(previewItems[index]),
        ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final crossAxisCount = _gridCrossAxisCount(context);
    final skeletonCount = crossAxisCount * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const ImageSkeletonLoader(width: 150, height: 18),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: _gridDelegate(context),
          itemCount: skeletonCount,
          itemBuilder: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const ImageSkeletonLoader(showLogo: true),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const ImageSkeletonLoader(width: 100, height: 14),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const ImageSkeletonLoader(width: 60, height: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
