import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lost_item_card.dart';
import 'view_all_icon_button.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';
import '../../data/fallback_data.dart';
import '../../../../features/news/data/models/news_item.dart';
import '../../../../features/news/presentation/screens/news_detail_page.dart';

class LostItemsNearbySection extends StatefulWidget {
  const LostItemsNearbySection({super.key});

  @override
  State<LostItemsNearbySection> createState() => _LostItemsNearbySectionState();
}

class _LostItemsNearbySectionState extends State<LostItemsNearbySection> {
  final PageController _pageController = PageController();

  void _navigateToDetail(BuildContext context, Map<String, String> item) {
    final newsItem = NewsItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorName: 'Mytogether User',
      authorAvatar: '',
      content: item['description']!,
      imageUrls: [item['imageUrl']!],
      likesCount: 12,
      commentsCount: 4,
      timeAgo: item['timeAgo']!,
      location: 'Nearby',
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewsDetailPage(item: newsItem)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use high-quality fallback data
    final List<Map<String, String>> lostItems = FallbackData.lostItems.take(10).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lost Items Nearby',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LostAndFoundPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250, // Increased from 240 to 250 to fix 4px overflow ((110+12)*2 = 244)
          child: PageView.builder(
            controller: _pageController,
            itemCount: (lostItems.length / 2).ceil(),
            itemBuilder: (context, pageIndex) {
              final firstItemIndex = pageIndex * 2;
              final secondItemIndex = firstItemIndex + 1;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    LostItemCard(
                      description: lostItems[firstItemIndex]['description']!,
                      imageUrl: lostItems[firstItemIndex]['imageUrl']!,
                      timeAgo: lostItems[firstItemIndex]['timeAgo']!,
                      onTap: () => _navigateToDetail(context, lostItems[firstItemIndex]),
                    ),
                    if (secondItemIndex < lostItems.length)
                      LostItemCard(
                        description: lostItems[secondItemIndex]['description']!,
                        imageUrl: lostItems[secondItemIndex]['imageUrl']!,
                        timeAgo: lostItems[secondItemIndex]['timeAgo']!,
                        onTap: () => _navigateToDetail(context, lostItems[secondItemIndex]),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
