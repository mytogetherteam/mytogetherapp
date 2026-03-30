import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lost_item_card.dart';
import 'view_all_icon_button.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_item_detail_page.dart';
import '../../data/fallback_data.dart';

class LostItemsNearbySection extends StatefulWidget {
  const LostItemsNearbySection({super.key});

  @override
  State<LostItemsNearbySection> createState() => _LostItemsNearbySectionState();
}

class _LostItemsNearbySectionState extends State<LostItemsNearbySection> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    // Use high-quality fallback data
    final List<Map<String, String>> lostItems = FallbackData.lostItems;

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
                      description: lostItems[firstItemIndex]['description'] ?? '',
                      imageUrl: lostItems[firstItemIndex]['imageUrl'] ?? '',
                      timeAgo: lostItems[firstItemIndex]['timeAgo'] ?? '',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LostItemDetailPage(
                              description: lostItems[firstItemIndex]['description'] ?? '',
                              imageUrl: lostItems[firstItemIndex]['imageUrl'] ?? '',
                              timeAgo: lostItems[firstItemIndex]['timeAgo'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                    if (secondItemIndex < lostItems.length)
                      LostItemCard(
                        description: lostItems[secondItemIndex]['description'] ?? '',
                        imageUrl: lostItems[secondItemIndex]['imageUrl'] ?? '',
                        timeAgo: lostItems[secondItemIndex]['timeAgo'] ?? '',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LostItemDetailPage(
                                description: lostItems[secondItemIndex]['description'] ?? '',
                                imageUrl: lostItems[secondItemIndex]['imageUrl'] ?? '',
                                timeAgo: lostItems[secondItemIndex]['timeAgo'] ?? '',
                              ),
                            ),
                          );
                        },
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
