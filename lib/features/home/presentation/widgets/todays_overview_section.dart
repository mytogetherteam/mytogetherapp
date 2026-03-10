import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'food_menu_item_card.dart';
import 'image_skeleton_loader.dart';
import 'view_all_icon_button.dart';
import '../screens/today_overview_detail_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/menu_item_dto.dart';
import '../../data/models/trending_item_dto.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_service.dart';

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
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final pos = await LocationService().getCurrentPosition();
    
    final section = await RestaurantRepository.instance.getTrendingItems(
      lat: activeLoc?.latitude ?? pos.latitude,
      lon: activeLoc?.longitude ?? pos.longitude,
      radiusKm: 10.0,
    );
    return section.items.map((t) => _trendingToMenuItem(t)).toList();
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
      originalPrice: t.originalPrice,
      displayPrice: t.displayPrice,
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
            backgroundColor: const Color(0xFFED3A72),
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

  @override
  Widget build(BuildContext context) {
    if (widget.items != null) {
      if (widget.items!.isEmpty) return const SizedBox.shrink();
      return _buildContent(context, widget.items!, widget.title ?? 'Trending Near By');
    }

    return FutureBuilder<List<MenuItemDto>>(
      future: _menuItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildContent(context, snapshot.data!, widget.title ?? 'Trending Near By');
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
            mainAxisSpacing: 24,
            childAspectRatio: 0.85,
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
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.85,
          ),
          itemCount: displayItems.length > 6 ? 6 : displayItems.length,
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
              originalPrice: item.originalPrice,
              displayPrice: item.displayPrice,
              onFavoriteToggle: () => _toggleFavorite(item),
            );
          },
        ),
      ],
    );
  }
}
