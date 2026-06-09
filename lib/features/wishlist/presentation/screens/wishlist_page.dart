import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/home/presentation/screens/restaurant_detail_page.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/food_menu_item_card.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/restaurant_card.dart';

import '../../data/models/wishlist_item_dto.dart';
import '../../data/repositories/wishlist_repository.dart';

/// "Saved Items" — shows the current user's wishlist for both menu items
/// and shops. Backed by /api/user/wishlist/*.
class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final WishlistRepository _repo = WishlistRepository.instance;

  bool _loading = true;
  List<WishlistItemDto> _menuItems = [];
  List<WishlistItemDto> _shops = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.listMenuItems(size: 100),
        _repo.listShops(size: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _menuItems = results[0];
        _shops = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(WishlistItemDto item) async {
    try {
      await _repo.removeById(item.id);
      if (!mounted) return;
      setState(() {
        _menuItems.removeWhere((it) => it.id == item.id);
        _shops.removeWhere((it) => it.id == item.id);
      });
      AppDialog.showToast(context, context.tr('wishlist.removed'));
    } catch (_) {
      if (!mounted) return;
      AppDialog.showToast(
        context,
        context.tr('wishlist.remove_failed'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          context.tr('profile.saved_items'),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: context.trArgs('wishlist.tab_menu', {'count': '${_menuItems.length}'})),
            Tab(text: context.trArgs('wishlist.tab_shops', {'count': '${_shops.length}'})),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMenuItemList(),
                _buildShopList(),
              ],
            ),
    );
  }

  Widget _buildMenuItemList() {
    if (_menuItems.isEmpty) {
      return _buildEmpty(
        title: context.tr('wishlist.empty_title'),
        subtitle: context.tr('wishlist.empty_sub'),
      );
    }
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.85,
        ),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          final menu = item.menuItem;
          final shopId = menu?.shopId ?? menu?.shop?.id;
          return FoodMenuItemCard(
            id: (menu?.id ?? item.menuItemId ?? 0).toString(),
            restaurantId: (shopId ?? 0).toString(),
            title: menu?.displayName ?? context.tr('wishlist.menu_item'),
            price: menu?.effectivePrice ?? 0,
            currency: '฿',
            imagePath: menu?.imageUrl ?? '',
            restaurantName: menu?.shop?.displayName ?? '',
            isFavorite: true,
            originalPrice:
                (menu?.hasDiscount ?? false) ? menu?.originalPrice : null,
            isAvailable: menu?.isAvailable ?? true,
            // Replicates the Food-tab flow: tapping opens the restaurant page
            // and plays the highlight/float animation on this menu item.
            forceRestaurantNavigation: true,
            showFavoriteToast: false,
            onFavoriteToggle: () => _removeItem(item),
          );
        },
      ),
    );
  }

  Widget _buildShopList() {
    if (_shops.isEmpty) {
      return _buildEmpty(
        title: context.tr('wishlist.empty_shops_title'),
        subtitle: context.tr('wishlist.empty_shops_sub'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        itemCount: _shops.length,
        itemBuilder: (context, index) {
          final item = _shops[index];
          final shop = item.shop;
          return RestaurantCard(
            name: shop?.displayName ?? context.tr('common.shop'),
            category: '',
            rating: shop?.ratingAvg ?? 0,
            reviewCount: shop?.ratingCount ?? 0,
            distance: '',
            imagePath: shop?.bannerImageUrl ?? '',
            logoPath: shop?.logoUrl,
            isFavorite: true,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
            showFavoriteToast: false,
            onFavoriteToggle: () => _removeItem(item),
            onTap: () {
              final shopId = shop?.id;
              if (shopId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RestaurantDetailPage(
                    id: shopId.toString(),
                    name: shop?.displayName,
                    logoPath: shop?.logoUrl,
                    imagePath: shop?.bannerImageUrl,
                    rating: shop?.ratingAvg,
                    reviewCount: shop?.ratingCount,
                    isFavorite: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty({required String title, required String subtitle}) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
