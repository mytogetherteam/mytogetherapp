import 'dart:async';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/nearby_restaurant_list_item_skeleton.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../../../../core/auth/auth_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../features/auth/data/repositories/user_location_repository.dart';
import 'restaurant_detail_page.dart';

class AllRestaurantsPage extends StatefulWidget {
  const AllRestaurantsPage({super.key});

  @override
  State<AllRestaurantsPage> createState() => _AllRestaurantsPageState();
}

class _AllRestaurantsPageState extends State<AllRestaurantsPage> {
  late final PaginatedListController<Restaurant> _pagination;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  final Map<String, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _pagination = PaginatedListController<Restaurant>(
      pageSize: 20,
      initialPage: 0,
      itemKey: (r) => r.id,
      fetchPage: _fetchShops,
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(_scrollController);
    _pagination.loadInitial();
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<PaginatedPage<Restaurant>> _fetchShops(int page) async {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final pos = LocationService().cachedPosition;
    final lat = activeLoc?.latitude ?? pos?.latitude ?? LocationService.defaultLat;
    final lon =
        activeLoc?.longitude ?? pos?.longitude ?? LocationService.defaultLon;

    final List<Restaurant> results;
    bool hasMore;
    if (AuthService().isLoggedIn) {
      final pageResult = await RestaurantRepository.instance.getShopProfilesPage(
        page: page + 1,
        size: _pagination.pageSize,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery,
        originLat: lat,
        originLon: lon,
      );
      results = pageResult.restaurants;
      hasMore = pageResult.hasMore;
    } else {
      final pageResult = await RestaurantRepository.instance.getNearbyShopsPage(
        lat: lat,
        lon: lon,
        page: page,
        size: _pagination.pageSize,
        search: _searchQuery,
      );
      results = pageResult.restaurants;
      hasMore = pageResult.hasMore;
    }

    return PaginatedPage(
      items: results,
      hasMore: hasMore,
    );
  }

  Future<void> _onRefresh() async {
    await _pagination.refresh();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
        });
        _pagination.refresh();
      }
    });
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus =
        !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
    setState(() {
      _localFavorites[restaurant.id] = newStatus;
    });

    try {
      await RestaurantRepository.instance.toggleShopFavorite(
        int.tryParse(restaurant.id) ?? 0,
        newStatus,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _localFavorites[restaurant.id] = !newStatus;
        });
      }
    }
  }

  bool get _showPaginationFooter => _pagination.showFooter;

  @override
  Widget build(BuildContext context) {
    final restaurants = _pagination.items;
    final isLoading = _pagination.isInitialLoading;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 70,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: context.tr('restaurant.search_hint'),
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    PhosphorIcons.magnifyingGlass,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            PhosphorIcons.xCircleFill,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
          titleSpacing: 0,
          actions: const [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(width: 20),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.primary,
                child: isLoading
                    ? _buildSkeletonList()
                    : restaurants.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 12, bottom: 16),
                        itemCount:
                            restaurants.length + (_showPaginationFooter ? 1 : 0),
                        itemBuilder: (context, index) {
                          _pagination.onItemVisible(index);
                          if (index == restaurants.length) {
                            return PaginationListFooter(
                              isLoading: _pagination.isLoadingMore,
                              showEndMessage: !_pagination.hasMore,
                            );
                          }

                          final data = restaurants[index];
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
                            isFavorite:
                                _localFavorites[data.id] ?? data.isFavorite,
                            onFavoriteToggle: () => _toggleFavorite(data),
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: 24,
                              left: 20,
                              right: 20,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RestaurantDetailPage(
                                    id: data.id,
                                    name: data.name,
                                    category: data.category,
                                    rating: data.rating,
                                    distance: data.distance,
                                    imagePath: data.imagePath,
                                    logoPath: data.logoPath,
                                    deliveryTime: data.deliveryTime,
                                    status: data.status,
                                    isFavorite:
                                        _localFavorites[data.id] ??
                                        data.isFavorite,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: 5,
      itemBuilder: (_, _) => const NearbyRestaurantListItemSkeleton(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.bag, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            context.tr('restaurant.no_restaurants'),
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('restaurant.adjust_filters'),
            style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
