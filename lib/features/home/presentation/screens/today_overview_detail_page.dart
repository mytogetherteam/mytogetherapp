import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/food_menu_item_card.dart';
import '../widgets/food_menu_item_skeleton.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/models/menu_item_dto.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import '../../../../core/location/location_service.dart';
import '../../data/models/trending_item_dto.dart';

class TodayOverviewDetailPage extends StatefulWidget {
  const TodayOverviewDetailPage({super.key});

  @override
  State<TodayOverviewDetailPage> createState() => _TodayOverviewDetailPageState();
}

class _TodayOverviewDetailPageState extends State<TodayOverviewDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final List<MenuItemDto> _items = [];
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasMore = true;
  final Map<String, bool> _localFavorites = {};
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && 
        !_isLoading && 
        _hasMore) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
    });
    
    try {
      final List<MenuItemDto> items;
      final activeLoc = UserLocationRepository.instance.activeLocation;
      final pos = await LocationService().getCurrentPosition();
      
      final section = await RestaurantRepository.instance.getTrendingItems(
        lat: activeLoc?.latitude ?? pos.latitude,
        lon: activeLoc?.longitude ?? pos.longitude,
        page: 0,
        size: _pageSize,
      );
      items = section.items.map((t) => _mapTrendingToMenuItem(t)).toList();
      _hasMore = items.length >= _pageSize;

      if (mounted) {
        setState(() {
          _items.clear();
          _items.addAll(items);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  MenuItemDto _mapTrendingToMenuItem(TrendingItemDto t) {
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
      displayPrice: t.displayPrice,
      rating: t.rating,
      reviewCount: t.reviewCount,
      distanceKm: t.distanceKm,
      estimatedTime: t.estimatedTime,
      deliveryFee: t.deliveryFee,
      originalDeliveryFee: t.originalDeliveryFee,
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
      // We don't necessarily need to reload everything here as we have the local override,
      // but we could refresh if needed.
    } catch (e) {
      // Rollback on error
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

  Future<void> _onRefresh() async {
    await _loadInitialData();
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    
    try {
      final nextPage = _currentPage + 1;
      final activeLoc = UserLocationRepository.instance.activeLocation;
      final pos = await LocationService().getCurrentPosition();
      
      final section = await RestaurantRepository.instance.getTrendingItems(
        lat: activeLoc?.latitude ?? pos.latitude,
        lon: activeLoc?.longitude ?? pos.longitude,
        page: nextPage,
        size: _pageSize,
      );
      
      final moreItems = section.items.map((t) => _mapTrendingToMenuItem(t)).toList();
      
      if (mounted) {
        setState(() {
          _items.addAll(moreItems);
          _currentPage = nextPage;
          _hasMore = moreItems.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const displayTitle = 'Trending Near By';
    final int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          displayTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.black.withValues(alpha: 0.05),
            height: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: _items.isEmpty && _isLoading
            ? GridView.builder(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 48.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.75,
                ),
                itemCount: crossAxisCount * 3,
                itemBuilder: (context, index) => const FoodMenuItemSkeleton(),
              )
            : GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 48.0),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.85,
                ),
                itemCount: _items.length + (_isLoading && _hasMore ? 2 : 0),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const FoodMenuItemSkeleton();
                  }
                  final item = _items[index];
                  return FoodMenuItemCard(
                    id: item.id,
                    restaurantId: item.restaurantId,
                    title: item.title,
                    price: item.price,
                    currency: item.currency,
                    imagePath: item.imagePath,
                    restaurantName: item.restaurantName,
                    isFavorite: _localFavorites[item.id] ?? item.isFavorite,
                    displayPrice: item.displayPrice,
                    rating: item.rating,
                    reviewCount: item.reviewCount,
                    distanceKm: item.distanceKm,
                    estimatedTime: item.estimatedTime,
                    deliveryFee: item.deliveryFee,
                    originalDeliveryFee: item.originalDeliveryFee,
                    onFavoriteToggle: () => _toggleFavorite(item),
                    forceRestaurantNavigation: true,
                    isAvailable: item.isAvailable,
                    publishStatus: item.publishStatus,
                  );
                },
              ),
      ),
    );
  }
}
