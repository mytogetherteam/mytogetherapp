import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/login_page.dart';
import 'package:mytogetherapp/features/home/data/models/master_category_dto.dart';
import 'package:mytogetherapp/features/home/data/models/shop_dto.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/image_skeleton_loader.dart';
import 'package:mytogetherapp/features/home/presentation/screens/menu_detail_page.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_detail_page.dart';
import 'package:mytogetherapp/features/search/data/models/search_shop_dto.dart';
import 'package:mytogetherapp/features/search/data/models/search_filters.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytogetherapp/core/presentation/widgets/menu_image_placeholder.dart';

enum SearchFlowState { idle, typing, searched }

class FoodSearchPage extends StatefulWidget {
  /// When provided, the page opens with this query pre-filled and runs the
  /// search immediately (used by the Popular Categories rail).
  final String? initialQuery;

  /// When set, applies `masterCategoryId` to shop search filters (from
  /// `GET /api/user/master-menu-categories/popular`).
  final int? initialMasterCategoryId;

  /// When true, opens the filter sheet automatically after the page loads
  /// (used by the Food header filter icon).
  final bool openFilterOnLoad;

  const FoodSearchPage({
    super.key,
    this.initialQuery,
    this.initialMasterCategoryId,
    this.openFilterOnLoad = false,
  });

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
  List<String> _recentSearches = [];
  List<MasterCategoryDto> _popularCategories = [];
  List<MasterCategoryDto> _masterCategories = [];
  List<CuisineTypeDto> _cuisineTypes = [];
  bool _isLoadingCuisines = false;
  bool _isLoadingCategories = true;
  bool _isLoadingMasterCategories = false;
  bool _isLoading = false;
  String? _errorMessage;
  SearchFilters _filters = SearchFilters.empty;
  String? _selectedCategoryName;

  /// Selectable minimum-rating thresholds for the Rating filter.
  static const List<double> _ratingOptions = [4.5, 4.0, 3.5, 3.0];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadPopularCategories();
    _ensureMasterCategoriesLoaded();
    final seed = widget.initialQuery?.trim();
    if (widget.initialMasterCategoryId != null) {
      _filters = SearchFilters(
        masterCategoryId: widget.initialMasterCategoryId,
      );
    }
    if (seed != null && seed.isNotEmpty) {
      _searchController.text = seed;
      _currentState = SearchFlowState.searched;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch(seed, persistRecent: true);
      });
    } else if (widget.initialMasterCategoryId != null) {
      // Opened pre-filtered by a category: browse matching shops immediately.
      _currentState = SearchFlowState.searched;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch('', persistRecent: false);
      });
    } else if (!widget.openFilterOnLoad) {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPopularCategories() async {
    if (!AuthService().isLoggedIn) {
      if (mounted) setState(() => _isLoadingCategories = false);
      return;
    }
    try {
      final categories = await RestaurantRepository.instance
          .getPopularMasterCategories(limit: 16)
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _popularCategories = categories;
          _isLoadingCategories = false;
          if (_filters.masterCategoryId != null &&
              _selectedCategoryName == null) {
            for (final c in categories) {
              if (c.id == _filters.masterCategoryId) {
                _selectedCategoryName = c.displayName;
                break;
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _ensureMasterCategoriesLoaded() async {
    if (_masterCategories.isNotEmpty || _isLoadingMasterCategories) return;
    setState(() => _isLoadingMasterCategories = true);
    try {
      final categories = await RestaurantRepository.instance
          .getMasterCategories()
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _masterCategories = categories;
          _isLoadingMasterCategories = false;
          if (_filters.masterCategoryId != null &&
              _selectedCategoryName == null) {
            for (final c in categories) {
              if (c.id == _filters.masterCategoryId) {
                _selectedCategoryName = c.displayName;
                break;
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMasterCategories = false);
    }
  }

  Future<void> _ensureCuisineTypesLoaded() async {
    if (_cuisineTypes.isNotEmpty || _isLoadingCuisines) return;
    setState(() => _isLoadingCuisines = true);
    try {
      final cuisines = await RestaurantRepository.instance
          .getCuisineTypes()
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _cuisineTypes = cuisines;
          _isLoadingCuisines = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCuisines = false);
    }
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

  Future<void> _removeRecentSearch(String term) async {
    final updated = _recentSearches.where((s) => s != term).toList();
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
      if (_filters.hasAny) {
        setState(() {
          _currentState = SearchFlowState.searched;
          _errorMessage = null;
        });
        _runSearch('', persistRecent: false);
      } else {
        setState(() {
          _currentState = SearchFlowState.idle;
          _shopResults = [];
          _errorMessage = null;
          _isLoading = false;
        });
      }
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
    if (_filters.hasAny) {
      setState(() {
        _currentState = SearchFlowState.searched;
        _errorMessage = null;
      });
      _runSearch('', persistRecent: false);
    } else {
      setState(() {
        _currentState = SearchFlowState.idle;
        _shopResults = [];
        _errorMessage = null;
        _isLoading = false;
      });
      _searchFocus.requestFocus();
    }
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

  /// Filters shops/menu by master category id (`GET /api/user/search`).
  void _onPopularCategoryTap(MasterCategoryDto category) {
    setState(() {
      _filters = _filters.copyWith(masterCategoryId: category.id);
      _selectedCategoryName = category.displayName;
      _currentState = SearchFlowState.searched;
    });
    _searchFocus.unfocus();
    _runSearch(_searchController.text.trim(), persistRecent: false);
  }

  String _categoryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  Future<void> _runSearch(String query, {required bool persistRecent}) async {
    if (!AuthService().isLoggedIn) {
      setState(() {
        _isLoading = false;
        _errorMessage = context.tr('food.search_sign_in');
        _shopResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loc = await _resolveLocation();
      final shopPage = await RestaurantRepository.instance.searchShopsWithMenu(
        lat: loc.lat,
        lon: loc.lon,
        query: query,
        radiusKm: _filters.radiusKm ?? 99999.0,
        size: _currentState == SearchFlowState.searched ? 20 : 6,
        filters: _filters,
      );

      if (persistRecent) {
        await _saveRecentSearch(query);
      }

      if (mounted) {
        setState(() {
          _shopResults = shopPage.shops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = context.tr('food.search_failed');
          _shopResults = [];
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
          category: s.category ?? context.tr('common.restaurant'),
          rating: s.rating,
          distance: context.trArgs('food.distance_km',
              {'distance': s.distance.toStringAsFixed(1)}),
          imagePath: _imageUrl(s.bannerImageUrl),
          logoPath: _imageUrl(s.logoUrl),
          deliveryTime:
              s.estimatedTime ?? context.tr('food.default_delivery_time'),
          status: s.isOpen ? context.tr('common.open') : context.tr('common.closed'),
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
              _buildFilterChipsRow(),
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
                        hintText: context.tr('food.search_hint'),
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
        actionLabel: AuthService().isLoggedIn ? null : context.tr('common.sign_in'),
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
      case SearchFlowState.searched:
        return _buildResultsList();
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
                context.tr('food.recent_searches'),
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
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeRecentSearch(term),
                            behavior: HitTestBehavior.opaque,
                            child: Icon(
                              PhosphorIcons.x,
                              size: 14,
                              color: Colors.black38,
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
            if (_isLoadingCategories)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CustomLoadingIndicator(size: 28),
                ),
              )
            else if (_popularCategories.isNotEmpty) ...[
              Text(
                context.tr('food.popular_categories'),
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
                itemCount: _popularCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.6,
                ),
                itemBuilder: (context, index) {
                  final category = _popularCategories[index];
                  final imageUrl = _categoryImageUrl(category.imageUrl);
                  return GestureDetector(
                    onTap: () => _onPopularCategoryTap(category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl.isEmpty
                                ? Icon(
                                    PhosphorIcons.forkKnife,
                                    size: 22,
                                    color: Colors.grey[400],
                                  )
                                : CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                    imageUrl: imageUrl,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) =>
                                        const ImageSkeletonLoader(
                                      width: 32,
                                      height: 32,
                                    ),
                                    errorWidget: (_, _, _) => Icon(
                                      PhosphorIcons.forkKnife,
                                      size: 22,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Applies the client-side Rating threshold (`minRating`) to the shop
  /// results, since the backend search only supports a `topRated` boolean.
  List<SearchShopDto> get _filteredShopResults {
    final min = _filters.minRating;
    if (min == null) return _shopResults;
    return _shopResults.where((s) => s.shop.rating >= min).toList();
  }

  /// Search results: each shop is shown with its preview menu items (matches
  /// the home cards). The menu-only list is intentionally not shown here.
  Widget _buildResultsList() {
    final shops = _filteredShopResults;
    if (!_isLoading && shops.isEmpty) {
      final query = _searchController.text.trim();
      return _buildMessageState(
        icon: PhosphorIcons.magnifyingGlass,
        title: query.isEmpty
            ? context.tr('food.no_filter_results')
            : context.trArgs('food.no_restaurants', {'query': query}),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: shops.length,
      itemBuilder: (context, index) {
        return _buildSearchedRestaurantBlock(shops[index]);
      },
    );
  }

  void _updateFilters(SearchFilters filters) {
    setState(() => _filters = filters);
    final query = _searchController.text.trim();
    if (query.isNotEmpty || filters.hasAny) {
      setState(() => _currentState = SearchFlowState.searched);
      _runSearch(query, persistRecent: false);
    } else {
      setState(() {
        _currentState = SearchFlowState.idle;
        _shopResults = [];
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Filter chips row (Master Category, Rating, Cuisines, Dietary)
  // ---------------------------------------------------------------------------

  Widget _buildFilterChipsRow() {
    final categoryActive = _filters.masterCategoryId != null;
    final ratingActive = _filters.minRating != null;
    final cuisineActive = _filters.cuisineTypeIds.isNotEmpty;
    final dietaryActive = _filters.dietaryCount > 0;

    final categoryLabel = categoryActive
        ? (_selectedCategoryName ?? context.tr('food.master_category'))
        : context.tr('food.master_category');
    final ratingLabel = ratingActive
        ? context.trArgs(
            'food.rating_and_up',
            {'rating': _filters.minRating!.toStringAsFixed(1)},
          )
        : context.tr('food.rating');
    final distanceActive = _filters.radiusKm != null;
    final distanceLabel = distanceActive
        ? context.trArgs('food.around_km', {
            'km': _filters.radiusKm!.toStringAsFixed(0),
          })
        : context.tr('food.distance');
    final mealActive = _filters.mealTypes.isNotEmpty;
    final mealLabel = mealActive
        ? context.trArgs('food.meals_count', {
            'count': '${_filters.mealTypes.length}',
          })
        : context.tr('food.meal_time');
    final cuisineLabel = cuisineActive
        ? '${context.tr('food.cuisines')} (${_filters.cuisineTypeIds.length})'
        : context.tr('food.cuisines');
    final dietaryLabel = dietaryActive
        ? '${context.tr('food.dietary')} (${_filters.dietaryCount})'
        : context.tr('food.dietary');

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          _buildDropdownChip(
            label: categoryLabel,
            active: categoryActive,
            onTap: _openCategorySheet,
          ),
          const SizedBox(width: 8),
          _buildDropdownChip(
            label: ratingLabel,
            active: ratingActive,
            icon: PhosphorIcons.star,
            onTap: _openRatingSheet,
          ),
          const SizedBox(width: 8),
          _buildDropdownChip(
            label: distanceLabel,
            active: distanceActive,
            icon: PhosphorIcons.mapPin,
            onTap: _openDistanceSheet,
          ),
          const SizedBox(width: 8),
          _buildDropdownChip(
            label: mealLabel,
            active: mealActive,
            onTap: _openMealTypeSheet,
          ),
          const SizedBox(width: 8),
          _buildDropdownChip(
            label: cuisineLabel,
            active: cuisineActive,
            onTap: _openCuisineSheet,
          ),
          const SizedBox(width: 8),
          _buildDropdownChip(
            label: dietaryLabel,
            active: dietaryActive,
            onTap: _openDietarySheet,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final fg = active ? AppColors.primary : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: active ? AppColors.primary : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 3),
            Icon(PhosphorIcons.caretDown, size: 14, color: fg),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter selection sheets
  // ---------------------------------------------------------------------------

  Widget _sheetScaffold(
    BuildContext ctx, {
    required String title,
    required Widget child,
    Widget? footer,
    Widget? searchField,
  }) {
    // Cap the sheet at half the screen so large option lists scroll inside
    // instead of taking over the entire screen. Short lists stay compact
    // because the Column uses MainAxisSize.min.
    final maxHeight = MediaQuery.of(ctx).size.height * 0.5;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (searchField != null) ...[searchField, const SizedBox(height: 8)],
            Flexible(child: child),
            if (footer != null) ...[const SizedBox(height: 12), footer],
          ],
        ),
      ),
    );
  }

  /// Compact search field used inside filter sheets that have many options.
  Widget _buildSheetSearchField({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.magnifyingGlass,
            size: 18,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: context.tr('food.filter_search_hint'),
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? leadingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: Colors.amber[600]),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
            if (selected)
              Icon(PhosphorIcons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckTile({
    required String label,
    required bool checked,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: checked ? AppColors.primary : Colors.grey[400]!,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetFooter({
    required VoidCallback onReset,
    required VoidCallback onApply,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('food.reset'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('common.apply'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showFilterSheet({required WidgetBuilder builder}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: builder,
    );
  }

  Future<void> _openCategorySheet() async {
    await _ensureMasterCategoriesLoaded();
    if (!mounted) return;
    String query = '';
    await _showFilterSheet(
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final showSearch = _masterCategories.length > 10;
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? _masterCategories
                : _masterCategories
                    .where((c) => c.displayName.toLowerCase().contains(q))
                    .toList();

            return _sheetScaffold(
              sheetContext,
              title: this.context.tr('food.master_category'),
              searchField: showSearch
                  ? _buildSheetSearchField(
                      value: query,
                      onChanged: (v) => setSheetState(() => query = v),
                    )
                  : null,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (q.isEmpty)
                    _buildSelectableTile(
                      label: this.context.tr('food.all_categories'),
                      selected: _filters.masterCategoryId == null,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _selectedCategoryName = null;
                        _updateFilters(
                          _filters.copyWith(clearMasterCategoryId: true),
                        );
                      },
                    ),
                  if (_isLoadingMasterCategories)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CustomLoadingIndicator(size: 28)),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          this.context.tr('food.no_filter_results'),
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (c) => _buildSelectableTile(
                        label: c.displayName,
                        selected: _filters.masterCategoryId == c.id,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _selectedCategoryName = c.displayName;
                          _updateFilters(
                            _filters.copyWith(masterCategoryId: c.id),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openRatingSheet() async {
    await _showFilterSheet(
      builder: (sheetContext) {
        return _sheetScaffold(
          sheetContext,
          title: context.tr('food.rating'),
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildSelectableTile(
                label: context.tr('food.any_rating'),
                selected: _filters.minRating == null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _updateFilters(_filters.copyWith(clearMinRating: true));
                },
              ),
              ..._ratingOptions.map(
                (r) => _buildSelectableTile(
                  leadingIcon: PhosphorIcons.starFill,
                  label: context.trArgs(
                    'food.rating_and_up',
                    {'rating': r.toStringAsFixed(1)},
                  ),
                  selected: _filters.minRating == r,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _updateFilters(_filters.copyWith(minRating: r));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _distanceOptions = [2.0, 5.0, 10.0, 20.0, 50.0];

  String _mealTypeLabel(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return context.tr('food.breakfast');
      case 'Lunch':
        return context.tr('food.lunch');
      case 'Dinner':
        return context.tr('food.dinner');
      default:
        return mealType;
    }
  }

  Future<void> _openDistanceSheet() async {
    await _showFilterSheet(
      builder: (sheetContext) {
        return _sheetScaffold(
          sheetContext,
          title: context.tr('food.distance'),
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildSelectableTile(
                label: context.tr('food.any_distance'),
                selected: _filters.radiusKm == null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _updateFilters(_filters.copyWith(clearRadiusKm: true));
                },
              ),
              ..._distanceOptions.map(
                (d) => _buildSelectableTile(
                  leadingIcon: PhosphorIcons.mapPin,
                  label: context.trArgs('food.around_km', {
                    'km': d.toStringAsFixed(0),
                  }),
                  selected: _filters.radiusKm == d,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _updateFilters(_filters.copyWith(radiusKm: d));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _mealOptions = ['Breakfast', 'Lunch', 'Dinner'];

  Future<void> _openMealTypeSheet() async {
    final draft = Set<String>.from(_filters.mealTypes);
    await _showFilterSheet(
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _sheetScaffold(
              sheetContext,
              title: context.tr('food.meal_time'),
              footer: _buildSheetFooter(
                onReset: () {
                  Navigator.pop(sheetContext);
                  _updateFilters(_filters.copyWith(mealTypes: const []));
                },
                onApply: () {
                  Navigator.pop(sheetContext);
                  _updateFilters(_filters.copyWith(mealTypes: draft.toList()));
                },
              ),
              child: ListView(
                shrinkWrap: true,
                children: _mealOptions.map((m) {
                  final on = draft.contains(m);
                  return _buildCheckTile(
                    label: _mealTypeLabel(m),
                    checked: on,
                    onTap: () => setSheetState(() {
                      if (on) {
                        draft.remove(m);
                      } else {
                        draft.add(m);
                      }
                    }),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCuisineSheet() async {
    await _ensureCuisineTypesLoaded();
    if (!mounted) return;
    final draft = Set<int>.from(_filters.cuisineTypeIds);
    String query = '';
    await _showFilterSheet(
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final showSearch = _cuisineTypes.length > 10;
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? _cuisineTypes
                : _cuisineTypes
                    .where((c) => c.displayName.toLowerCase().contains(q))
                    .toList();

            Widget content;
            if (_isLoadingCuisines) {
              content = const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CustomLoadingIndicator()),
              );
            } else if (_cuisineTypes.isEmpty) {
              content = Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  this.context.tr('food.no_cuisines'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              );
            } else if (filtered.isEmpty) {
              content = Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  this.context.tr('food.no_filter_results'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              );
            } else {
              content = ListView(
                shrinkWrap: true,
                children: filtered.map((c) {
                  final on = draft.contains(c.id);
                  return _buildCheckTile(
                    label: c.displayName,
                    checked: on,
                    onTap: () => setSheetState(() {
                      if (on) {
                        draft.remove(c.id);
                      } else {
                        draft.add(c.id);
                      }
                    }),
                  );
                }).toList(),
              );
            }

            return _sheetScaffold(
              sheetContext,
              title: this.context.tr('food.cuisines'),
              searchField: showSearch
                  ? _buildSheetSearchField(
                      value: query,
                      onChanged: (v) => setSheetState(() => query = v),
                    )
                  : null,
              footer: _cuisineTypes.isEmpty
                  ? null
                  : _buildSheetFooter(
                      onReset: () {
                        Navigator.pop(sheetContext);
                        _updateFilters(
                          _filters.copyWith(cuisineTypeIds: const []),
                        );
                      },
                      onApply: () {
                        Navigator.pop(sheetContext);
                        _updateFilters(
                          _filters.copyWith(cuisineTypeIds: draft.toList()),
                        );
                      },
                    ),
              child: content,
            );
          },
        );
      },
    );
  }

  Future<void> _openDietarySheet() async {
    var draft = _filters;
    await _showFilterSheet(
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _sheetScaffold(
              sheetContext,
              title: this.context.tr('food.dietary'),
              footer: _buildSheetFooter(
                onReset: () {
                  Navigator.pop(sheetContext);
                  _updateFilters(
                    _filters.copyWith(
                      isVegetarian: false,
                      isHalal: false,
                      isSpicy: false,
                    ),
                  );
                },
                onApply: () {
                  Navigator.pop(sheetContext);
                  _updateFilters(draft);
                },
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildCheckTile(
                    label: this.context.tr('food.vegetarian'),
                    checked: draft.isVegetarian,
                    onTap: () => setSheetState(
                      () => draft = draft.copyWith(
                        isVegetarian: !draft.isVegetarian,
                      ),
                    ),
                  ),
                  _buildCheckTile(
                    label: this.context.tr('food.halal'),
                    checked: draft.isHalal,
                    onTap: () => setSheetState(
                      () => draft = draft.copyWith(isHalal: !draft.isHalal),
                    ),
                  ),
                  _buildCheckTile(
                    label: this.context.tr('food.spicy'),
                    checked: draft.isSpicy,
                    onTap: () => setSheetState(
                      () => draft = draft.copyWith(isSpicy: !draft.isSpicy),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchedRestaurantBlock(SearchShopDto shopDto) {
    final shop = shopDto.shop;
    final menuItems = shopDto.menuItems;
    final logo = _imageUrl(shop.bannerImageUrl ?? shop.logoUrl);

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
                    child: _buildThumbnail(logo, shop.name, 48),
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
                            if (shop.rating > 0) ...[
                              Icon(
                                PhosphorIcons.starFill,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${shop.rating.toStringAsFixed(1)} · ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            Text(
                              context.trArgs('food.distance_km', {'distance': shop.distance.toStringAsFixed(1)}),
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
                  // Left-only padding so an overflowing list reveals a partial
                  // card flush against the right edge (a "peek" hinting scroll).
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: menuItems.length + 1,
                  itemBuilder: (context, index) {
                    if (index == menuItems.length) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () => _openRestaurant(shopDto),
                          child: SizedBox(
                            width: 80,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: _menuCardWidth(context),
                                  child: Center(
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        PhosphorIcons.arrowRight,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    final item = menuItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _openMenuItem(item, shopDto),
                        child: _buildCustomMenuItem(item, _menuCardWidth(context)),
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

  /// Width of a single menu-item card in the search-result rail. Sized so that
  /// ~3.5 cards are visible, which leaves the next card partially shown (a
  /// "peek") whenever the backend returns more items than fit on screen.
  double _menuCardWidth(BuildContext context) {
    const leftPad = 16.0;
    const spacing = 12.0;
    const visibleCards = 3.5;
    final available = MediaQuery.of(context).size.width - leftPad;
    final width = (available - spacing * 3) / visibleCards;
    return width.clamp(88.0, 110.0);
  }

  Widget _buildCustomMenuItem(SearchMenuItemPreviewDto item, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildThumbnail(_imageUrl(item.imageUrl), item.name, width, height: width),
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

  Widget _buildThumbnail(String url, String title, double width, {double? height}) {
    final h = height ?? width;
    if (url.isEmpty) {
      return SizedBox(
        width: width,
        height: h,
        child: MenuImagePlaceholder(title: title),
      );
    }
    return CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
      imageUrl: url,
      width: width,
      height: h,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => SizedBox(
        width: width,
        height: h,
        child: MenuImagePlaceholder(title: title),
      ),
    );
  }
}

