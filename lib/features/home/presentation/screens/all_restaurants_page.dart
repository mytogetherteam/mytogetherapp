import 'dart:async';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
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
  final List<Restaurant> _restaurants = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  final Map<String, bool> _localFavorites = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Fetches a page of shops. Logged-in users browse the authenticated
  /// catalog (`GET /api/user/shop-profile`, server-side search + client-side
  /// distance); guests fall back to the public geo "nearby" listing.
  Future<List<Restaurant>> _fetchShops(int page) async {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    final pos = LocationService().cachedPosition;
    final lat = activeLoc?.latitude ?? pos?.latitude ?? LocationService.defaultLat;
    final lon =
        activeLoc?.longitude ?? pos?.longitude ?? LocationService.defaultLon;

    if (AuthService().isLoggedIn) {
      return RestaurantRepository.instance.getShopProfiles(
        page: page + 1,
        size: _pageSize,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery,
        originLat: lat,
        originLon: lon,
      );
    }

    return RestaurantRepository.instance.getNearbyShops(
      lat: lat,
      lon: lon,
      page: page,
      size: _pageSize,
      search: _searchQuery,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData({bool showLoading = true}) async {
    if (_isLoading) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    setState(() {
      _currentPage = 0;
      _restaurants.clear();
      _hasMore = true;
    });

    try {
      final results = await _fetchShops(_currentPage);

      if (mounted) {
        setState(() {
          final existingIds = _restaurants.map((r) => r.id).toSet();
          for (var res in results) {
            if (!existingIds.contains(res.id)) {
              _restaurants.add(res);
            }
          }
          _isLoading = false;
          _hasMore = results.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trArgs('restaurant.load_error', {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      final results = await _fetchShops(_currentPage);

      if (mounted) {
        setState(() {
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            final existingIds = _restaurants.map((r) => r.id).toSet();
            for (var res in results) {
              if (!existingIds.contains(res.id)) {
                _restaurants.add(res);
              }
            }
            _hasMore = results.length >= _pageSize;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--; // Rollback page on error
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadInitialData(showLoading: false);
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
        });
        _loadInitialData();
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

  @override
  Widget build(BuildContext context) {
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
                child: _isLoading
                    ? _buildSkeletonList()
                    : _restaurants.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 12, bottom: 16),
                        itemCount: _restaurants.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _restaurants.length) {
                            return _buildLoadMoreIndicator();
                          }

                          final data = _restaurants[index];
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

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
