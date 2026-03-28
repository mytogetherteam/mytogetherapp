import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../home/data/repositories/restaurant_repository.dart';
import '../../../home/data/restaurant_data.dart';
import '../../../home/presentation/screens/restaurant_detail_page.dart';
import '../../data/search_storage.dart';

enum SearchFlowState { idle, typing, searched }

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  SearchFlowState _currentState = SearchFlowState.idle;

  List<String> _recentSearches = [];
  List<Map<String, String>> _categories = [];
  List<Restaurant> _searchResults = [];
  bool _isSearching = false;
  bool _hasUserSearchedBefore = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    Future.microtask(() => _searchFocus.requestFocus());
  }

  Future<void> _loadInitialData() async {
    await SearchStorage().init();
    final cats = await RestaurantRepository.instance.getFallbackCategories();

    final storage = SearchStorage();
    _hasUserSearchedBefore = storage.hasRecentSearches;
    _recentSearches = storage.recentSearches;

    if (mounted) {
      setState(() {
        _categories = cats;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      if (_currentState != SearchFlowState.idle) {
        setState(() => _currentState = SearchFlowState.idle);
      }
    } else {
      if (_currentState != SearchFlowState.typing) {
        setState(() => _currentState = SearchFlowState.typing);
      }
    }
  }

  Future<void> _onSearchSubmitted(String value) async {
    if (value.isNotEmpty) {
      await SearchStorage().addSearch(value);
      _recentSearches = SearchStorage().recentSearches;
      _hasUserSearchedBefore = true;

      setState(() {
        _currentState = SearchFlowState.searched;
        _isSearching = true;
      });
      _searchFocus.unfocus();

      final results = await RestaurantRepository.instance.searchFoodOrShop(
        value,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentState = SearchFlowState.idle;
    });
    _searchFocus.requestFocus();
  }

  Future<void> _onRecentTap(String term) async {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    _searchFocus.unfocus();
    await _onSearchSubmitted(term);
  }

  void _onCategoryTap(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    _searchFocus.unfocus();
    _onSearchSubmitted(term);
  }

  Future<void> _removeRecentSearch(String term) async {
    await SearchStorage().removeSearch(term);
    _recentSearches = SearchStorage().recentSearches;
    _hasUserSearchedBefore = SearchStorage().hasRecentSearches;
    if (mounted) setState(() {});
  }

  Future<void> _clearAllRecentSearches() async {
    await SearchStorage().clearAll();
    _recentSearches = [];
    _hasUserSearchedBefore = false;
    if (mounted) setState(() {});
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
                color: const Color(0xFFF3F4F6), // match light greyish blue
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    PhosphorIcons.magnifyingGlass(),
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
    switch (_currentState) {
      case SearchFlowState.idle:
        return _buildState1Idle();
      case SearchFlowState.typing:
        return _buildState2Typing();
      case SearchFlowState.searched:
        return _buildState3Searched();
    }
  }

  // --- STATE 1: IDLE ---
  Widget _buildState1Idle() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasUserSearchedBefore && _recentSearches.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey[400],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearAllRecentSearches,
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFED3A72),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches.map((term) {
                  return GestureDetector(
                    onTap: () => _onRecentTap(term),
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
                            PhosphorIcons.clock(),
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
              itemCount: _categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, index) {
                final category = _categories[index];
                return GestureDetector(
                  onTap: () => _onCategoryTap(category['name']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            category['name']!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

  // --- STATE 2: TYPING ---
  Widget _buildState2Typing() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggestions (Static for now but filtered from query)
          ...(_recentSearches
              .where(
                (s) => s.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ),
              )
              .map((suggestion) {
                return InkWell(
                  onTap: () => _onRecentTap(suggestion),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.magnifyingGlass(),
                              size: 20,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 14),
                            Text(
                              suggestion,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Colors.grey[200],
                        indent: 20,
                        endIndent: 20,
                      ),
                    ],
                  ),
                );
              })),

          const SizedBox(height: 8),

          // Typing Restaurants (Filtered from fallback)
          FutureBuilder<List<Restaurant>>(
            future: RestaurantRepository.instance.searchFoodOrShop(
              _searchController.text,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final results = snapshot.data!;
              return Column(
                children: results.take(3).map<Widget>((Restaurant restaurant) {
                  return InkWell(
                    onTap: () => _navigateToDetail(restaurant),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: restaurant.imagePath,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) =>
                                      Container(color: Colors.grey[200]),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      restaurant.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${restaurant.rating} · ${restaurant.deliveryTime} · ${restaurant.distance}',
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
                        Divider(
                          height: 1,
                          color: Colors.grey[200],
                          indent: 20,
                          endIndent: 20,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- STATE 3: SEARCHED ---
  Widget _buildState3Searched() {
    return Column(
      children: [
        // Filter Chips
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
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFED3A72)),
                )
              : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    'No results found for "${_searchController.text}"',
                    style: GoogleFonts.poppins(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final restaurant = _searchResults[index];
                    return _buildSearchedRestaurantBlock(restaurant);
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
          PhosphorIcons.slidersHorizontal(),
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
            const Icon(
              Icons.grid_view_outlined,
              size: 16,
              color: Colors.black54,
            ),
            const SizedBox(width: 6),
          ],
          if (label == 'Under 25 Min') ...[
            Icon(PhosphorIcons.lightning(), size: 16, color: Colors.black54),
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
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.black54,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchedRestaurantBlock(Restaurant restaurant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant Header
          InkWell(
            onTap: () => _navigateToDetail(restaurant),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: restaurant.logoPath,
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) =>
                          Container(color: Colors.grey[200]),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
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
                              PhosphorIcons.star(PhosphorIconsStyle.fill),
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${restaurant.rating} · ${restaurant.deliveryTime} · ${restaurant.distance}',
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
          ),
          const SizedBox(height: 12),
          // Horizontal Menu Items List (Popular Dishes)
          if (restaurant.popularDishes.isNotEmpty)
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: restaurant.popularDishes.length,
                itemBuilder: (context, index) {
                  final item = restaurant.popularDishes[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildCustomMenuItem(item),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200], indent: 16),
        ],
      ),
    );
  }

  Widget _buildCustomMenuItem(dynamic item) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.imagePath,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) =>
                  Container(color: Colors.grey[200]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '฿ ${item.price.toInt()}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFED3A72),
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
          ],
          Expanded(
            child: Text(
              item.title,
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

  void _navigateToDetail(Restaurant data) {
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
          latitude: data.latitude,
          longitude: data.longitude,
          popularDishes: data.popularDishes,
          recommendations: data.recommendations,
          hotDeals: data.hotDeals,
          isFavorite: data.isFavorite,
        ),
      ),
    );
  }
}
