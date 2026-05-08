import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/demo_food_search_data.dart';

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

  @override
  void initState() {
    super.initState();
    // Auto focus on open
    Future.microtask(() => _searchFocus.requestFocus());
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

  void _onSearchSubmitted(String value) {
    if (value.isNotEmpty) {
      if (_currentState != SearchFlowState.searched) {
        setState(() => _currentState = SearchFlowState.searched);
      }
      _searchFocus.unfocus();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentState = SearchFlowState.idle;
    });
    _searchFocus.requestFocus();
  }

  void _onRecentOrCategoryTap(String term) {
    _searchController.text = term;
    setState(() {
      _currentState = SearchFlowState.searched;
    });
    // Ensure caret is at the end of the text
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    _searchFocus.unfocus();
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
              Expanded(
                child: _buildBodyContent(),
              ),
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
              children: DemoFoodSearchData.recentSearches.map((term) {
                return GestureDetector(
                  onTap: () => _onRecentOrCategoryTap(term),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  // --- STATE 2: TYPING ---
  Widget _buildState2Typing() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggestions
          ...DemoFoodSearchData.suggestions.map((suggestion) {
            return InkWell(
              onTap: () => _onRecentOrCategoryTap(suggestion),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                  Divider(height: 1, color: Colors.grey[200], indent: 20, endIndent: 20),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 8),

          // Typing Restaurants
          ...DemoFoodSearchData.typingRestaurants.map((restaurant) {
            return InkWell(
              onTap: () => _onRecentOrCategoryTap(restaurant['name']),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: restaurant['image'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant['name'],
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
                                    '${restaurant['rating']} · ${restaurant['time']} · ${restaurant['distance']}',
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
          }),
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
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: DemoFoodSearchData.resultRestaurants.length,
            itemBuilder: (context, index) {
              final restaurant = DemoFoodSearchData.resultRestaurants[index];
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
        child: Icon(PhosphorIcons.slidersHorizontal(), size: 16, color: Colors.black87),
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
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
          ]
        ],
      ),
    );
  }

  Widget _buildSearchedRestaurantBlock(Map<String, dynamic> restaurant) {
    List<dynamic> badges = restaurant['badges'] ?? [];
    List<dynamic> menuItems = restaurant['menuItems'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: restaurant['logo'],
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${restaurant['rating']} · ${restaurant['time']} · ${restaurant['distance']}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: badges.map((badgeText) {
                            bool isPromo = badgeText.toString().contains('off');
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPromo ? Colors.green[50] : Colors.pink[50], // Very light green / pink
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPromo ? PhosphorIcons.sealPercent(PhosphorIconsStyle.fill) : PhosphorIcons.bicycle(),
                                    size: 14,
                                    color: isPromo ? const Color(0xFF22C55E) : AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    badgeText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isPromo ? const Color(0xFF22C55E) : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ]
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal Menu Items List
          SizedBox(
            height: 180, // Reduced height to decrease spacing to divider
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
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

  Widget _buildCustomMenuItem(Map<String, dynamic> item) {
    return SizedBox(
      width: 100, // Reduced width so 3.5 items fit on screen (strategy)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item['image'],
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '฿ ${item['price'].toInt()}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary, // Pink color
              height: 1.2,
            ),
          ),
          if (item['originalPrice'] != null && item['originalPrice'] > item['price']) ...[
            Text(
              '฿${item['originalPrice'].toInt()}',
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
          if (item['originalPrice'] == null || item['originalPrice'] <= item['price'])
            const SizedBox(height: 4), // Add a bit more spacing if no original price to keep things somewhat aligned
          Expanded(
            child: Text(
              item['name'],
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
}
