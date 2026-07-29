import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/network/media_url.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/shop_myday_viewer.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/features/home/data/repositories/restaurant_repository.dart';
import 'package:mytogetherapp/features/home/data/restaurant_data.dart' show Restaurant;
import 'package:mytogetherapp/features/auth/data/repositories/user_location_repository.dart';
import 'package:mytogetherapp/core/location/location_refresh_mixin.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/image_skeleton_loader.dart';

class AllShopMyDaysSection extends StatefulWidget {
  const AllShopMyDaysSection({super.key});

  @override
  State<AllShopMyDaysSection> createState() => _AllShopMyDaysSectionState();
}

class _AllShopMyDaysSectionState extends State<AllShopMyDaysSection> with LocationRefreshMixin {
  Future<List<Restaurant>>? _shopsWithStoriesFuture;

  @override
  void initState() {
    super.initState();
    _reloadStories();
  }

  @override
  void onActiveLocationChanged() {
    _reloadStories();
  }

  void _reloadStories() {
    setState(() {
      _shopsWithStoriesFuture = _loadShopsWithStories();
    });
  }

  Future<List<Restaurant>> _loadShopsWithStories() async {
    try {
      // Fetch shops that specifically have active MyDays using the dedicated API (random/global)
      // This endpoint does not require location or other parameters.
      final shops = await RestaurantRepository.instance.getShopsWithActiveMyDays(
        size: 30,
      ).timeout(const Duration(seconds: 10));

      debugPrint('AllShopMyDaysSection: API returned ${shops.length} shops with mydays');
      for (var shop in shops) {
        debugPrint('Shop ${shop.name} has ${shop.myDays.length} active mydays');
      }

      return shops;
    } catch (e) {
      debugPrint('AllShopMyDaysSection: API error or timeout: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _shopsWithStoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show skeleton loader
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          );
        }

        final List<Restaurant> shopsWithStories = snapshot.data ?? [];
        if (shopsWithStories.isEmpty) {
          return const SizedBox.shrink(); // Hide section if no stories available
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                context.tr('home.recent_updates') ?? 'Recent Updates',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: shopsWithStories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final shop = shopsWithStories[index];
                  return _buildStoryCard(context, shop, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStoryCard(BuildContext context, Restaurant shop, int index) {
    final storyImg = resolveMediaUrl(shop.myDays.first.imageUrl);
    final logoImg = resolveMediaUrl(shop.logoPath);

    return GestureDetector(
      onTap: () {
        ShopMyDayViewer.open(
          context,
          shopName: shop.name,
          shopLogoUrl: shop.logoPath,
          stories: shop.myDays,
          initialIndex: 0,
        );
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Story Background Image
              CachedNetworkImage(
                imageUrl: storyImg,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
              
              // Dark gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Shop Logo (Facebook Style Profile Pic)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: logoImg.isNotEmpty ? CachedNetworkImageProvider(logoImg) : null,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              // Shop Name (Bottom Left)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  shop.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
