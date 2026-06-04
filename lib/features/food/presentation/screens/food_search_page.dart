import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/login_page.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/features/home/presentation/screens/menu_detail_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_detail_page.dart';
import 'package:mytogetherapp/features/search/data/models/search_shop_dto.dart';
import 'package:mytogetherapp/features/search/data/search_repository.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/demo_food_search_data.dart';

enum SearchFlowState { idle, typing, searched }

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  static const _recentSearchesKey = 'food_search_recent';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  SearchFlowState _currentState = SearchFlowState.idle;
  Timer? _debounceTimer;

  List<SearchShopDto> _shopResults = [];
  List<MenuItemSearchResultDto> _menuItemResults = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    Future.microtask(() => _searchFocus.requestFocus());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentSearchesKey) ?? [];
    if (mounted) {
      setState(() {
        _recentSearches = stored;
      });
    }
  }

  Future<void> _saveRecentSearch(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final updated = [
      trimmed,
      ..._recentSearches.where((s) => s.toLowerCase() != trimmed.toLowerCase()),
    ].take(8).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, updated);
    if (mounted) {
      setState(() => _recentSearches = updated);
    }
  }

  Future<({double lat, double lon})> _resolveLocation() async {
    final activeLoc = UserLocationRepository.instance.activeLocation;
    if (activeLoc?.latitude != null && activeLoc?.longitude != null) {
      return (lat: activeLoc!.latitude!, lon: activeLoc.longitude!);
    }
    final pos = LocationService().cachedPosition ??
        await LocationService().getCurrentPosition();
    return (lat: pos.latitude, lon: pos.longitude);
  }

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      _debounceTimer?.cancel();
      setState(() {
        _currentState = SearchFlowState.idle;
        _shopResults = [];
        _menuItemResults = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _currentState = SearchFlowState.typing;
      _errorMessage = null;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _runSearch(value, persistRecent: false);
    });
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isEmpty) return;
    _debounceTimer?.cancel();
    setState(() => _currentState = SearchFlowState.searched);
    _searchFocus.unfocus();
    _runSearch(value, persistRecent: true);
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _currentState = SearchFlowState.idle;
      _shopResults = [];
      _menuItemResults = [];
      _errorMessage = null;
      _isLoading = false;
    });
    _searchFocus.requestFocus();
  }

  void _onRecentOrCategoryTap(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    setState(() => _currentState = SearchFlowState.searched);
    _searchFocus.unfocus();
    _runSearch(term, persistRecent: true);
  }

  Future<void> _runSearch(String query, {required bool persistRecent}) async {
    if (!AuthService().isLoggedIn) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in to search restaurants and menus.';
        _shopResults = [];
        _menuItemResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loc = await _resolveLocation();
      final results = await Future.wait([
        RestaurantRepository.instance.searchShopsWithMenu(
          lat: loc.lat,
          lon: loc.lon,
          query: query,
          size: _currentState == SearchFlowState.searched ? 20 : 6,
        ),
        SearchRepository.instance.searchMenuItems(query: query),
      ]);

      final shopPage = results[0] as SearchPageResult;
      final menuItems = results[1] as List<MenuItemSearchResultDto>;

      if (persistRecent) {
        await _saveRecentSearch(query);
      }

      if (mounted) {
        setState(() {
          _shopResults = shopPage.shops;
          _menuItemResults = menuItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Search failed. Please try again.';
          _shopResults = [];
          _menuItemResults = [];
        });
      }
    }
  }

  void _openRestaurant(SearchShopDto shop) {
    final s = shop.shop;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailPage(
          id: s.id.toString(),
          name: s.name,
          category: s.category ?? 'Restaurant',
          rating: s.rating,
          distance: '${s.distance.toStringAsFixed(1)} km',
          imagePath: _imageUrl(s.coverUrl ?? s.primaryPhotoUrl ?? s.logoUrl),
          logoPath: _imageUrl(s.logoUrl),
          deliveryTime: s.estimatedTime ?? '20-30 mins',
          status: s.isOpen ? 'Open' : 'Closed',
          isFavorite: s.isFavorite,
        ),
      ),
    );
  }

  void _openMenuItem(SearchMenuItemPreviewDto item, SearchShopDto shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuDetailPage(
          id: item.id.toString(),
          restaurantId: shop.shop.id.toString(),
          title: item.name,
          price: item.price,
          imagePath: _imageUrl(item.imageUrl),
          rating: shop.shop.rating,
          reviewCount: shop.shop.reviewCount,
          restaurantName: shop.shop.name,
        ),
      ),
    );
  }

  void _openMenuItemSearchResult(MenuItemSearchResultDto item) {
    if (item.shopId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuDetailPage(
          id: item.id.toString(),
          restaurantId: item.shopId.toString(),
          title: item.name,
          price: item.price,
          imagePath: _imageUrl(item.imageUrl),
          rating: 0,
          reviewCount: 0,
          restaurantName: item.shopName ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildBodyContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    PhosphorIcons.magnifyingGlass,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      textInputAction: TextInputAction.search,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search menus & restaurants',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[500],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_errorMessage != null) {
      return _buildMessageState(
        icon: PhosphorIcons.signIn,
        title: _errorMessage!,
        actionLabel: AuthService().isLoggedIn ? null : 'Sign in',
        onAction: AuthService().isLoggedIn
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
      );
    }

    if (_isLoading &&
        (_currentState == SearchFlowState.typing ||
            _currentState == SearchFlowState.searched)) {
      return const Center(child: CustomLoadingIndicator());
    }

    switch (_currentState) {
      case SearchFlowState.idle:
        return _buildState1Idle();
      case SearchFlowState.typing:
        return _buildState2Typing();
      case SearchFlowState.searched:
        return _buildState3Searched();
    }
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildState1Idle() {
    // Only the user's actual saved searches are shown; the "Recent Searches"
    // section is hidden entirely when there are none (no demo placeholders).
    final recent = _recentSearches;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recent.isNotEmpty) ...[
              Text(
                'Recent Searches',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[400],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recent.map((term) {
                  return GestureDetector(
                    onTap: () => _onRecentOrCategoryTap(term),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.clock,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            term,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
            ],
            Text(
              'Popular Categories',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[400],
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: DemoFoodSearchData.categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, index) {
                final category = DemoFoodSearchData.categories[index];
                return GestureDetector(
                  onTap: () => _onRecentOrCategoryTap(category['name']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category['name']!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          category['emoji']!,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildState2Typing() {
    if (!_isLoading &&
        _shopResults.isEmpty &&
        _menuItemResults.isEmpty &&
        _searchController.text.trim().isNotEmpty) {
      return _buildMessageState(
        icon: PhosphorIcons.magnifyingGlass,
        title: 'No results for "${_searchController.text.trim()}"',
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_menuItemResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Menu items',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[400],
                ),
              ),
            ),
            ..._menuItemResults.take(5).map(_buildMenuItemSearchRow),
          ],
          if (_shopResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Restaurants',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[400],
                ),
              ),
            ),
            ..._shopResults.map(_buildTypingRestaurantRow),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItemSearchRow(MenuItemSearchResultDto item) {
    return InkWell(
      onTap: () => _openMenuItemSearchResult(item),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildThumbnail(_imageUrl(item.imageUrl), 48),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      if (item.shopName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.shopName!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '฿${item.price.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 20, endIndent: 20),
        ],
      ),
    );
  }

  Widget _buildTypingRestaurantRow(SearchShopDto shopDto) {
    final shop = shopDto.shop;
    final image = _imageUrl(
      shop.coverUrl ?? shop.primaryPhotoUrl ?? shop.logoUrl,
    );

    return InkWell(
      onTap: () => _openRestaurant(shopDto),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildThumbnail(image, 60),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            '${shop.rating.toStringAsFixed(1)} · ${shop.distance.toStringAsFixed(1)} km',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 20, endIndent: 20),
        ],
      ),
    );
  }

  Widget _buildState3Searched() {
    if (!_isLoading && _shopResults.isEmpty) {
      return _buildMessageState(
        icon: PhosphorIcons.magnifyingGlass,
        title: 'No restaurants found for "${_searchController.text.trim()}"',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterIconButton(),
              const SizedBox(width: 8),
              _buildFilterChip('Category', true),
              const SizedBox(width: 8),
              _buildFilterChip('Under 25 Min', false),
              const SizedBox(width: 8),
              _buildFilterChip('Top Rated', false),
              const SizedBox(width: 8),
              _buildFilterChip('Offers', false),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: _shopResults.length,
            itemBuilder: (context, index) {
              return _buildSearchedRestaurantBlock(_shopResults[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterIconButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Icon(
          PhosphorIcons.slidersHorizontal,
          size: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool hasDropdown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label == 'Category') ...[
            const Icon(Icons.grid_view_outlined, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
          ],
          if (label == 'Under 25 Min') ...[
            Icon(PhosphorIcons.lightning, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasDropdown) ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchedRestaurantBlock(SearchShopDto shopDto) {
    final shop = shopDto.shop;
    final menuItems = shopDto.menuItems;
    final logo = _imageUrl(shop.logoUrl);

    return GestureDetector(
      onTap: () => _openRestaurant(shopDto),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildThumbnail(logo, 48),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.starFill,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${shop.rating.toStringAsFixed(1)} · ${shop.distance.toStringAsFixed(1)} km',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        if (shop.category != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            shop.category!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (menuItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _openMenuItem(item, shopDto),
                        child: _buildCustomMenuItem(item),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey[200], indent: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMenuItem(SearchMenuItemPreviewDto item) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildThumbnail(_imageUrl(item.imageUrl), 100, height: 100),
          ),
          const SizedBox(height: 8),
          Text(
            '฿ ${item.price.toInt()}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              height: 1.2,
            ),
          ),
          if (item.originalPrice != null &&
              item.originalPrice! > item.price) ...[
            Text(
              '฿${item.originalPrice!.toInt()}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
                decoration: TextDecoration.lineThrough,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
          ] else
            const SizedBox(height: 4),
          Expanded(
            child: Text(
              item.name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String url, double width, {double? height}) {
    final h = height ?? width;
    if (url.isEmpty) {
      return Container(
        width: width,
        height: h,
        color: Colors.grey[200],
        child: Icon(PhosphorIcons.image, color: Colors.grey[400], size: 20),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: h,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => Container(
        width: width,
        height: h,
        color: Colors.grey[200],
        child: Icon(PhosphorIcons.image, color: Colors.grey[400], size: 20),
      ),
    );
  }
}
