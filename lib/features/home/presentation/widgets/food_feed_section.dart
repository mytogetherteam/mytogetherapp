import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'image_skeleton_loader.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../screens/restaurant_detail_page.dart';
import 'food_list_item_card.dart';
import 'food_menu_item_card.dart';

/// Reusable section widget for any of the 5 food tab feed endpoints.
/// Matches the style of TodaysOverviewSection (grid, skeleton, retry).
class FoodFeedSection extends StatefulWidget {
  final String
  feedType; // right-now | for-you | hot-deals | trending | popular-dishes
  final String title;
  final IconData? titleIcon;

  /// Called with `true` when data loaded but was empty, `false` when data is present.
  final ValueChanged<bool>? onEmpty;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final int layoutType; // 1: Grid (Default), 2: Horizontal Feed

  const FoodFeedSection({
    super.key,
    required this.feedType,
    required this.title,
    this.titleIcon,
    this.onEmpty,
    required this.latitude,
    required this.longitude,
    this.radiusKm = 10.0,
    this.layoutType = 1,
  });

  @override
  State<FoodFeedSection> createState() => _FoodFeedSectionState();
}

class _FoodFeedSectionState extends State<FoodFeedSection> {
  late Future<ShopFeedSectionDto> _future;
  final Map<int, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<ShopFeedSectionDto> _fetch() => RestaurantRepository.instance
      .getFoodTabFeed(
        feedType: widget.feedType,
        lat: widget.latitude,
        lon: widget.longitude,
        radiusKm: widget.radiusKm,
      )
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => ShopFeedSectionDto(items: _getFallbackItems()),
      );

  List<ShopFeedItemDto> _getFallbackItems() {
    // Hardcoded fallback items when API times out
    final items = [
      ShopFeedItemDto(
        id: 1,
        name: 'Mohinga',
        imageUrl:
            'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400&h=300&fit=crop',
        price: 180.0,
        rating: 4.8,
        reviewCount: 210,
        shopId: 1,
        shopName: 'Rangoon Tea House Bangkok',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿180',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 2,
        name: 'Lahpet Thoke (Tea Leaf Salad)',
        imageUrl:
            'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=400&h=300&fit=crop',
        price: 150.0,
        rating: 4.7,
        reviewCount: 185,
        shopId: 1,
        shopName: 'Rangoon Tea House Bangkok',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿150',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 3,
        name: 'Shan Noodles (Dry)',
        imageUrl:
            'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&h=300&fit=crop',
        price: 100.0,
        rating: 4.5,
        reviewCount: 88,
        shopId: 2,
        shopName: 'ThaNaKa Myanmar Restaurant',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿100',
        distanceKm: 1.8,
        estimatedTime: '20-30 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 4,
        name: 'Nan Gyi Thoke',
        imageUrl:
            'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400&h=300&fit=crop',
        price: 120.0,
        rating: 4.8,
        reviewCount: 167,
        shopId: 3,
        shopName: 'The Burma Food House',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿120',
        distanceKm: 3.1,
        estimatedTime: '30-40 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 5,
        name: 'Rangoon Signature Milk Tea',
        imageUrl:
            'https://images.unsplash.com/photo-1556742502-ec7c0e9f34b6?w=400&h=300&fit=crop',
        price: 80.0,
        rating: 4.6,
        reviewCount: 205,
        shopId: 1,
        shopName: 'Rangoon Tea House Bangkok',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿80',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      ),
      ShopFeedItemDto(
        id: 6,
        name: 'Slow-Braised Pork Belly Curry',
        imageUrl:
            'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=400&h=300&fit=crop',
        price: 220.0,
        originalPrice: 260.0,
        rating: 4.5,
        reviewCount: 134,
        shopId: 1,
        shopName: 'Rangoon Tea House Bangkok',
        isFavorite: false,
        currency: '฿',
        displayPrice: '฿220',
        distanceKm: 2.4,
        estimatedTime: '25-35 min',
        deliveryFee: '฿30',
      )
    ];
    items.shuffle();
    return items.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopFeedSectionDto>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }
        if (snapshot.hasError) {
          debugPrint('[FoodFeedSection] Error: ${snapshot.error}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEmpty?.call(true);
          });
          // Show fallback content instead of empty widget
          return _buildContent(_getFallbackItems());
        }
        final items = snapshot.data?.items ?? [];
        if (items.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEmpty?.call(true);
          });
          // Show fallback content instead of empty widget
          return _buildContent(_getFallbackItems());
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onEmpty?.call(false);
        });
        return _buildContent(items);
      },
    );
  }

  // ── Content ─────────────────────────────────────────────────────────────
  Widget _buildContent(List<ShopFeedItemDto> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.layoutType == 2)
          _buildLayout2(items)
        else
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.77,
            ),
            itemCount: items.length > 4 ? 4 : items.length,
            itemBuilder: (context, i) {
              final item = items[i];
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
              );
            },
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _toggleFavorite(ShopFeedItemDto item) async {
    final newStatus = !(_localFavorites[item.id] ?? item.isFavorite);
    final messenger = ScaffoldMessenger.of(context);

    // Immediate local feedback
    setState(() {
      _localFavorites[item.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleMenuFavorite(
        item.id,
        newStatus,
      );
      // No longer refreshing the future here to prevent flickering.
      // The local state _localFavorites handles the immediate color change.

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'Added to favorites' : 'Removed from favorites',
            ),
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

  // ── Skeleton ─────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _shimmerBox(width: 150, height: 20, radius: 8),
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
            childAspectRatio: 0.77,
          ),
          itemCount: MediaQuery.of(context).size.width > 600 ? 4 : 4,
          itemBuilder: (_, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const ImageSkeletonLoader(),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(width: 100, height: 14, radius: 6),
                    const SizedBox(height: 4),
                    _shimmerBox(width: 60, height: 14, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ImageSkeletonLoader(width: width, height: height),
    );
  }

  Widget _buildLayout2(List<ShopFeedItemDto> items) {
    // Group items into pairs of 2 for each page swipe
    final int pageCount = (items.length / 2).ceil();

    return SizedBox(
      height: 290, // Height for 2 cards vertically
      child: PageView.builder(
        itemCount: pageCount > 10
            ? 10
            : pageCount, // Cap at 10 pages (20 items)
        padEnds: false,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (context, pageIndex) {
          final startIndex = pageIndex * 2;
          final itemsOnPage = items.skip(startIndex).take(2).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: itemsOnPage.map((item) {
                return FoodListItemCard(
                  title: item.name,
                  description: '', // Description not in DTO
                  price: item.price,
                  originalPrice: item.originalPrice ?? 0.0,
                  currency: item.currency,
                  imagePath: item.imageUrl ?? '',
                  isFavorite: _localFavorites[item.id] ?? item.isFavorite,
                  displayPrice: item.displayPrice,
                  rating: item.rating,
                  reviewCount: item.reviewCount,
                  distanceKm: item.distanceKm,
                  estimatedTime: item.estimatedTime,
                  deliveryFee: item.deliveryFee,
                  originalDeliveryFee: item.originalDeliveryFee,
                  onFavoriteToggle: () => _toggleFavorite(item),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantDetailPage(
                          id: item.shopId.toString(),
                          name: item.shopName,
                          targetMenuItemId: item.id.toString(),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
