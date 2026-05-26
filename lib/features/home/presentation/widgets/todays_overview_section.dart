import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'food_menu_item_card.dart';
import 'image_skeleton_loader.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/features/cart/data/cart_repository.dart';
import 'package:mytogetherapp/features/cart/data/cart_manager.dart';
import 'package:mytogetherapp/features/cart/data/models/cart_dto.dart';
import 'view_all_icon_button.dart';
import '../screens/today_overview_detail_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/menu_item_dto.dart';
import '../../data/models/trending_item_dto.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_service.dart';
import '../../data/fallback_data.dart';

class TodaysOverviewSection extends StatefulWidget {
  final String? title;
  final List<MenuItemDto>? items;

  const TodaysOverviewSection({
    super.key,
    this.title,
    this.items,
  });

  @override
  State<TodaysOverviewSection> createState() => _TodaysOverviewSectionState();
}

class _TodaysOverviewSectionState extends State<TodaysOverviewSection> {
  Future<List<MenuItemDto>>? _menuItemsFuture;
  final Map<String, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    if (widget.items == null) {
      // Home page: fetch trending from API
      _menuItemsFuture = _fetchTrending();
    }
  }

  Future<List<MenuItemDto>> _fetchTrending() async {
    try {
      final activeLoc = UserLocationRepository.instance.activeLocation;
      // Use cached GPS or default — avoid blocking on browser geolocation API
      final pos = LocationService().cachedPosition;
      final lat = activeLoc?.latitude ?? pos?.latitude ?? LocationService.defaultLat;
      final lon = activeLoc?.longitude ?? pos?.longitude ?? LocationService.defaultLon;
      
      final section = await RestaurantRepository.instance.getTrendingItems(
        lat: lat,
        lon: lon,
        radiusKm: 10.0,
        size: 10,
      ).timeout(const Duration(seconds: 5));
      return section.items.map((t) => _trendingToMenuItem(t)).toList();
    } catch (e) {
      debugPrint('TodaysOverviewSection: API error or timeout: $e');
      return []; // Trigger fallback in builder
    }
  }

  MenuItemDto _trendingToMenuItem(TrendingItemDto t) {
    return MenuItemDto(
      id: t.id.toString(),
      restaurantId: t.shopId.toString(),
      restaurantName: t.shopName,
      title: t.name,
      price: t.price,
      currency: t.currency,
      imagePath: t.imageUrl,
      category: '',
      isFavorite: t.isFavorite,
      rating: t.rating,
      reviewCount: t.reviewCount,
      distanceKm: t.distanceKm,
      estimatedTime: t.estimatedTime,
      deliveryFee: t.deliveryFee,
      originalDeliveryFee: t.originalDeliveryFee,
      originalPrice: t.originalPrice,
      displayPrice: t.displayPrice,
      isAvailable: t.isAvailable,
      publishStatus: t.publishStatus,
    );
  }

  Future<void> _toggleFavorite(MenuItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    
    // Immediate local feedback
    setState(() {
      _localFavorites[item.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleMenuFavorite(
        int.tryParse(item.id) ?? 0,
        newStatus,
      );
      // No longer refreshing the future here to prevent flickering.
      // The local state _localFavorites handles the immediate color change.
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Added to favorites' : 'Removed from favorites'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _localFavorites[item.id] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to update favorite. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToCart(MenuItemDto item) async {
    final menuItemId = int.tryParse(item.id);
    final shopId = int.tryParse(item.restaurantId);
    if (menuItemId == null || shopId == null || shopId <= 0) return;

    try {
      await CartRepository.instance.addToCart(AddToCartRequest(
        menuItemId: menuItemId,
        quantity: 1,
        shopId: shopId,
      ));
      CartManager.instance.invalidateCache();
      if (mounted) {
        AppDialog.showToast(context, 'Added to cart');
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showToast(context, 'Failed to add: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items != null) {
      if (widget.items!.isEmpty) return const SizedBox.shrink();
      return _buildContent(context, widget.items!, widget.title ?? 'Trending Near By');
    }

    return FutureBuilder<List<MenuItemDto>>(
      future: _menuItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) { // Modified condition
          return _buildSkeleton();
        }

        final displayItems = (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty)
            ? FallbackData.trendingItems.take(10).toList()
            : snapshot.data!.take(10).toList();

        return _buildContent(context, displayItems, widget.title ?? 'Trending Near By'); // Use displayItems
      },
    );
  }

  // --- Skeleton ---
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Near By',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: MediaQuery.of(context).size.width > 600 ? 4 : 4,
          itemBuilder: (_, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: const ImageSkeletonLoader(),
              )),
              const SizedBox(height: 6),
              _shimmerBox(width: 100, height: 14, radius: 6),
              const SizedBox(height: 4),
              _shimmerBox(width: 60, height: 14, radius: 6),
            ],
          ),
        ),
      ],
    );
  }



  Widget _shimmerBox({required double width, required double height, double radius = 8}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ImageSkeletonLoader(width: width, height: height),
    );
  }

  Widget _buildContent(BuildContext context, List<MenuItemDto> displayItems, String displayTitle) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayTitle,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TodayOverviewDetailPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
          itemCount: displayItems.length > (MediaQuery.of(context).size.width > 600 ? 5 : 6) ? (MediaQuery.of(context).size.width > 600 ? 5 : 6) : displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            return FoodMenuItemCard(
              id: item.id,
              restaurantId: item.restaurantId,
              title: item.title,
              price: item.price,
              currency: item.currency,
              imagePath: item.imagePath,
              restaurantName: item.restaurantName,
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
              onAddToCart: () => _addToCart(item),
              forceRestaurantNavigation: true,
              isAvailable: item.isAvailable,
              publishStatus: item.publishStatus,
            );
          },
        ),
      ],
    );
  }
}
