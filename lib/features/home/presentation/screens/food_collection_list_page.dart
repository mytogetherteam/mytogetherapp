import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/utils/pagination_scroll.dart';
import 'package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart';
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import 'package:mytogetherapp/features/food/presentation/screens/food_search_page.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/restaurant_data.dart' show Restaurant;
import '../widgets/restaurant_card.dart';
import '../widgets/nearby_restaurant_list_item_skeleton.dart';
import 'restaurant_detail_page.dart';

/// Which "see all" feed this page renders.
enum FoodCollectionKind { trending, popular }

/// Full-screen, paginated list page for the Trending and Popular feeds.
/// Both variants show the search bar at the top (which opens the full search
/// page); the data source is chosen from [kind].
class FoodCollectionListPage extends StatefulWidget {
  final FoodCollectionKind kind;

  const FoodCollectionListPage({super.key, required this.kind});

  @override
  State<FoodCollectionListPage> createState() => _FoodCollectionListPageState();
}

class _FoodCollectionListPageState extends State<FoodCollectionListPage> {
  final List<Restaurant> _restaurants = [];
  final Map<String, bool> _localFavorites = {};
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
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

  Future<List<Restaurant>> _fetchPage(int page) async {
    final coords =
        await UserLocationRepository.instance.resolveActiveCoordinates();
    switch (widget.kind) {
      case FoodCollectionKind.trending:
        return RestaurantRepository.instance.getTrendingShops(
          lat: coords.lat,
          lon: coords.lon,
          page: page,
          size: _pageSize,
        );
      case FoodCollectionKind.popular:
        return RestaurantRepository.instance.getPopularShops(
          lat: coords.lat,
          lon: coords.lon,
          page: page,
          size: _pageSize,
        );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData({bool showLoading = true}) async {
    if (_isLoading) return;
    setState(() {
      if (showLoading) _isLoading = true;
      _currentPage = 1;
      _restaurants.clear();
      _hasMore = true;
    });

    try {
      final results = await _fetchPage(_currentPage);
      if (!mounted) return;
      setState(() {
        final existing = _restaurants.map((r) => r.id).toSet();
        _restaurants.addAll(results.where((r) => existing.add(r.id)));
        _isLoading = false;
        _hasMore = results.length >= _pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;

    final wasNearEnd = PaginationScroll.wasNearEnd(_scrollController);
    setState(() => _isLoadingMore = true);
    PaginationScroll.maintainAfterPageAppend(
      _scrollController,
      wasNearEnd: wasNearEnd,
    );

    try {
      _currentPage++;
      final results = await _fetchPage(_currentPage);
      if (!mounted) return;
      setState(() {
        if (results.isEmpty) {
          _hasMore = false;
        } else {
          final existing = _restaurants.map((r) => r.id).toSet();
          _restaurants.addAll(results.where((r) => existing.add(r.id)));
          _hasMore = results.length >= _pageSize;
        }
        _isLoadingMore = false;
      });
      PaginationScroll.maintainAfterPageAppend(
        _scrollController,
        wasNearEnd: wasNearEnd,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--;
        });
        PaginationScroll.maintainAfterPageAppend(
          _scrollController,
          wasNearEnd: wasNearEnd,
        );
      }
    }
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final newStatus =
        !(_localFavorites[restaurant.id] ?? restaurant.isFavorite);
    setState(() => _localFavorites[restaurant.id] = newStatus);
    try {
      await RestaurantRepository.instance.toggleShopFavorite(
        int.tryParse(restaurant.id) ?? 0,
        newStatus,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _localFavorites[restaurant.id] = !newStatus);
      }
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FoodSearchPage()),
    );
  }

  String get _title => switch (widget.kind) {
        FoodCollectionKind.trending => context.tr('food.trending'),
        FoodCollectionKind.popular => context.tr('food.popular'),
      };

  String get _emoji => switch (widget.kind) {
        FoodCollectionKind.trending => '🔥',
        FoodCollectionKind.popular => '👑',
      };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          toolbarHeight: 70,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 16),
            child: _buildSearchBar(),
          ),
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _loadInitialData(showLoading: false),
          child: _isLoading
              ? _buildSkeleton()
              : _restaurants.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.magnifyingGlass,
              color: Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('food.search_hint'),
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            _title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  bool get _showPaginationFooter => _isLoadingMore || !_hasMore;

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _restaurants.length + 1 + (_showPaginationFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeading();
        final dataIndex = index - 1;
        if (dataIndex == _restaurants.length) {
          return PaginationListFooter(
            isLoading: _isLoadingMore,
            showEndMessage: !_hasMore,
          );
        }
        final data = _restaurants[dataIndex];
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
          isFavorite: _localFavorites[data.id] ?? data.isFavorite,
          onFavoriteToggle: () => _toggleFavorite(data),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
          onTap: () => Navigator.push(
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
                isFavorite: _localFavorites[data.id] ?? data.isFavorite,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildHeading(),
        ...List.generate(5, (_) => const NearbyRestaurantListItemSkeleton()),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeading(),
        const SizedBox(height: 80),
        Center(
          child: Column(
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
            ],
          ),
        ),
      ],
    );
  }
}
