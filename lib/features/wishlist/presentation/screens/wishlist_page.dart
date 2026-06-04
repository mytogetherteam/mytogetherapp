import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/gradient_text.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

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
      AppDialog.showToast(context, 'Removed from saved items.');
    } catch (_) {
      if (!mounted) return;
      AppDialog.showToast(
        context,
        'Could not remove item. Please try again.',
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
          'Saved Items',
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
            Tab(text: 'Menu Items (${_menuItems.length})'),
            Tab(text: 'Shops (${_shops.length})'),
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
        title: 'No saved items yet',
        subtitle: 'Tap the heart on any dish to keep it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _menuItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          return _MenuWishlistTile(
            item: item,
            onRemove: () => _removeItem(item),
          );
        },
      ),
    );
  }

  Widget _buildShopList() {
    if (_shops.isEmpty) {
      return _buildEmpty(
        title: 'No saved shops yet',
        subtitle: 'Tap the heart on any restaurant to save it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _shops.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _shops[index];
          return _ShopWishlistTile(
            item: item,
            onRemove: () => _removeItem(item),
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

String _absoluteImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return '${ApiClient.baseUrl}/$path';
}

class _MenuWishlistTile extends StatelessWidget {
  final WishlistItemDto item;
  final VoidCallback onRemove;

  const _MenuWishlistTile({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final menu = item.menuItem;
    final name = menu?.displayName ?? 'Menu item';
    final imageUrl = _absoluteImageUrl(menu?.imageUrl);
    final priceText = menu?.price != null
        ? '฿${menu!.price!.toStringAsFixed(0)}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: Colors.grey[100]),
                      errorWidget: (_, _, _) => Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.fastfood_rounded,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.fastfood_rounded,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (priceText != null) ...[
                  const SizedBox(height: 6),
                  GradientText(
                    priceText,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (menu?.isAvailable == false) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Currently unavailable',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.red[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.favorite_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _ShopWishlistTile extends StatelessWidget {
  final WishlistItemDto item;
  final VoidCallback onRemove;

  const _ShopWishlistTile({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final shop = item.shop;
    final name = shop?.displayName ?? 'Shop';
    final logoUrl = _absoluteImageUrl(shop?.logoUrl);
    final coverUrl = _absoluteImageUrl(shop?.coverUrl);
    final imageUrl = coverUrl.isNotEmpty ? coverUrl : logoUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: Colors.grey[100]),
                      errorWidget: (_, _, _) => Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.storefront_rounded,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.storefront_rounded,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (shop?.ratingAvg ?? 0).toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${shop?.ratingCount ?? 0})',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                if (shop?.isOpen == false) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Closed',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.red[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.favorite_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
