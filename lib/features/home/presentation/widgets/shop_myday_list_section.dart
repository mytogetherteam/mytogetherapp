import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/network/media_url.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/features/home/data/models/shop_dto.dart';
import 'package:mytogetherapp/features/home/presentation/widgets/shop_myday_viewer.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';

class ShopMyDayListSection extends StatelessWidget {
  final String shopName;
  final String? shopLogoUrl;
  final List<ShopMyDayDto> stories;

  const ShopMyDayListSection({
    super.key,
    required this.shopName,
    this.shopLogoUrl,
    required this.stories,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Stories', // Fallback, could use context.tr('restaurant.stories') if it exists
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: stories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final story = stories[index];
              return _buildStoryThumbnail(context, story, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoryThumbnail(
      BuildContext context, ShopMyDayDto story, int index) {
    final storyImg = resolveMediaUrl(story.imageUrl);
    final logoImg = resolveMediaUrl(shopLogoUrl);

    return GestureDetector(
      onTap: () {
        ShopMyDayViewer.open(
          context,
          shopName: shopName,
          shopLogoUrl: shopLogoUrl,
          stories: stories,
          initialIndex: index,
        );
      },
      child: Container(
        width: 110,
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
            ],
          ),
        ),
      ),
    );
  }
}
