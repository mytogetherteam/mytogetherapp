import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'image_skeleton_loader.dart';
import '../../data/models/shop_feed_item_dto.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../screens/restaurant_detail_page.dart';
import 'food_list_item_card.dart';
import 'food_menu_item_card.dart';
import 'restaurant_ordering_filter_chips.dart';

/// Reusable section widget for any of the 5 food tab feed endpoints.
/// Matches the style of TodaysOverviewSection (grid, skeleton, retry).
class FoodFeedSection extends StatefulWidget {
  final String feedType; // right-now | for-you | hot-deals | trending | popular-dishes
  final String title;
  final IconData? titleIcon;
  /// Called with `true` when data loaded but was empty, `false` when data is present.
  final ValueChanged<bool>? onEmpty;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final int layoutType; // 1: Grid (Default), 2: Horizontal Feed
  /// When true, shows Delivery / Go & Eat chips and filters by shop ordering.
  final bool showOrderingFilter;

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
    this.showOrderingFilter = false,
  });

  @override
  State<FoodFeedSection> createState() => _FoodFeedSectionState();
}

class _FoodFeedSectionState extends State<FoodFeedSection> {
  late Future<ShopFeedSectionDto> _future;
  final Map<int, bool> _localFavorites = {};
  RestaurantOrderingFilter _filter = RestaurantOrderingFilter.delivery;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void didUpdateWidget(covariant FoodFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      setState(() {
        _future = _fetch();
      });
    }
  }

  Future<ShopFeedSectionDto> _fetch() =>
      RestaurantRepository.instance.getFoodTabFeed(
        feedType: widget.feedType,
        lat: widget.latitude,
        lon: widget.longitude,
        radiusKm: widget.radiusKm,
      );

  List<ShopFeedItemDto> _filtered(List<ShopFeedItemDto> items) {
    if (!widget.showOrderingFilter) return items;
    return items
        .where(
          (item) => _filter == RestaurantOrderingFilter.delivery
              ? item.deliveryEnabled
              : !item.deliveryEnabled,
        )
        .toList();
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEmpty?.call(true);
          });
          return const SizedBox.shrink();
        }
        final allItems = snapshot.data?.items ?? [];
        if (allItems.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEmpty?.call(true);
          });
          return const SizedBox.shrink();
        }

        final items = _filtered(allItems);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Keep page visible when filter empties a tab; only mark empty
            // when the unfiltered feed itself has no items.
            widget.onEmpty?.call(false);
          }
        });

        if (widget.showOrderingFilter && items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleRow(),
              const SizedBox(height: 12),
              RestaurantOrderingFilterChips(
                selected: _filter,
                onChanged: (value) {
                  if (value == _filter) return;
                  setState(() => _filter = value);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Text(
                  context.tr(
                    _filter == RestaurantOrderingFilter.delivery
                        ? 'restaurants.empty_delivery'
                        : 'restaurants.empty_visit_only',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          );
        }

        return _buildContent(items);
      },
    );
  }

  Widget _buildTitleRow() {
    return Padding(
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
    );
  }

  // ── Content ─────────────────────────────────────────────────────────────
  Widget _buildContent(List<ShopFeedItemDto> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleRow(),
        if (widget.showOrderingFilter) ...[
          const SizedBox(height: 12),
          RestaurantOrderingFilterChips(
            selected: _filter,
            onChanged: (value) {
              if (value == _filter) return;
              setState(() => _filter = value);
            },
          ),
        ],
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
              childAspectRatio: 0.85,
            ),
            itemCount: items.length > 20 ? 20 : items.length,
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

  // ── Skeleton ─────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _shimmerBox(width: 150, height: 20, radius: 8),
        ),
        if (widget.showOrderingFilter) ...[
          const SizedBox(height: 12),
          const RestaurantOrderingFilterChips(
            selected: RestaurantOrderingFilter.delivery,
            onChanged: _noopFilter,
          ),
        ],
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
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const ImageSkeletonLoader(showLogo: true),
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

  static void _noopFilter(RestaurantOrderingFilter _) {}

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
      height: 264, // Height for 2 compact cards vertically
      child: PageView.builder(
        itemCount: pageCount > 10 ? 10 : pageCount, // Cap at 10 pages (20 items)
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
                  displayPrice: item.displayPrice,
                  rating: item.rating,
                  reviewCount: item.reviewCount,
                  distanceKm: item.distanceKm,
                  estimatedTime: item.estimatedTime,
                  id: item.id.toString(),
                  isAvailable: item.isAvailable,
                  publishStatus: item.publishStatus,
                  restaurantId: item.shopId.toString(),
                  deliveryEnabled: item.deliveryEnabled,
                  operatingHours: item.operatingHours,
                  restaurantStatus: item.restaurantStatus,
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
