import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'food_menu_item_card.dart';
import 'image_skeleton_loader.dart';
import 'view_all_icon_button.dart';
import '../screens/today_overview_detail_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/menu_item_dto.dart';
import '../../data/models/trending_item_dto.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';

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
  Future<List<TrendingItemDto>>? _trendingFuture;
  final Map<String, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    if (widget.items == null) {
      _trendingFuture = _fetchTrending();
    }
  }

  Future<List<TrendingItemDto>> _fetchTrending() async {
    try {
      final coords =
          await UserLocationRepository.instance.resolveActiveCoordinates();
      final section = await RestaurantRepository.instance.getTrendingItems(
        lat: coords.lat,
        lon: coords.lon,
        radiusKm: 10.0,
        size: 10,
      ).timeout(const Duration(seconds: 8));
      return section.items;
    } catch (e) {
      debugPrint('TodaysOverviewSection: API error or timeout: $e');
      return [];
    }
  }

  Future<void> _toggleFavorite(TrendingItemDto item) async {
    final itemId = item.id.toString();
    final newStatus = !(_localFavorites[itemId] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    
    // Immediate local feedback
    setState(() {
      _localFavorites[itemId] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleMenuFavorite(
        item.id,
        newStatus,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _localFavorites[itemId] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('common.favorite_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavoriteMenuItem(MenuItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _localFavorites[item.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleMenuFavorite(
        int.tryParse(item.id) ?? 0,
        newStatus,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _localFavorites[item.id] = !newStatus;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('common.favorite_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items != null) {
      if (widget.items!.isEmpty) return const SizedBox.shrink();
      return _buildMenuItemContent(
        context,
        widget.items!,
        widget.title ?? context.tr('home.trending_nearby'),
      );
    }

    return FutureBuilder<List<TrendingItemDto>>(
      future: _trendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildSkeleton(context);
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final displayItems = snapshot.data!.take(10).toList();

        return _buildTrendingContent(
          context,
          displayItems,
          widget.title ?? context.tr('home.trending_nearby'),
        );
      },
    );
  }

  // --- Skeleton ---
  Widget _buildSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('home.trending_nearby'),
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

  Widget _buildTrendingContent(
    BuildContext context,
    List<TrendingItemDto> displayItems,
    String displayTitle,
  ) {
    final maxItems = MediaQuery.of(context).size.width > 600 ? 5 : 6;
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 5 : 2;

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
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: displayItems.length > maxItems
              ? maxItems
              : displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            final itemId = item.id.toString();
            return FoodMenuItemCard(
              id: itemId,
              restaurantId: item.shopId.toString(),
              title: item.name,
              price: item.price,
              currency: item.currency,
              imagePath: item.imageUrl,
              restaurantName: item.shopName,
              isFavorite: _localFavorites[itemId] ?? item.isFavorite,
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
        ),
      ],
    );
  }

  Widget _buildMenuItemContent(
    BuildContext context,
    List<MenuItemDto> displayItems,
    String displayTitle,
  ) {
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
              onFavoriteToggle: () => _toggleFavoriteMenuItem(item),
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
