import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lost_item_card.dart';
import 'view_all_icon_button.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';

class LostItemsNearbySection extends StatefulWidget {
  const LostItemsNearbySection({super.key});

  @override
  State<LostItemsNearbySection> createState() => _LostItemsNearbySectionState();
}

class _LostItemsNearbySectionState extends State<LostItemsNearbySection> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    // Dummy data for Lost Items
    final List<Map<String, String>> lostItems = [
      {
        'description': 'နောက်ဆုံးရ သတင်း၊ အထူးသတင်း၊ ကမ္ဘာနဲ့ မြန်မာရေးရာ သတင်းတွေ၊ ဗီဒီယိုနဲ့ ရုပ်သံ သတင်းတွေ၊ ဆောင်းပါးတွေကို ဘီ...',
        'imageUrl': 'https://images.unsplash.com/photo-1547949003-9792a18a2601?q=80&w=600&auto=format&fit=crop', // Backpack
        'timeAgo': '4min ago',
      },
      {
        'description': 'Lorem ipsum dolor sit amet consectetur. Pulvinar ut sed leo risus sit ut accumsan condimen...',
        'imageUrl': 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?q=80&w=600&auto=format&fit=crop', // Wallet/Keys
        'timeAgo': '4min ago',
      },
      {
        'description': 'Lost black leather wallet containing ID and credit cards near Siam Square. Please contact...',
        'imageUrl': 'https://images.unsplash.com/photo-1627123424574-724758594e93?q=80&w=600&auto=format&fit=crop', // Wallet
        'timeAgo': '15min ago',
      },
      {
        'description': 'Found a set of keys with a blue keychain in Lumphini Park. Message me to identify.',
        'imageUrl': 'https://images.unsplash.com/photo-1582139329536-e7284fece509?q=80&w=600&auto=format&fit=crop', // Keys
        'timeAgo': '1hour ago',
      },
      {
        'description': 'Found an iPhone 13 with a clear case near MBK Center. Locked. If this is yours, please message.',
        'imageUrl': 'https://images.unsplash.com/photo-1632733711679-5292d6676184?q=80&w=600&auto=format&fit=crop', // Phone
        'timeAgo': '2hours ago',
      },
      {
        'description': 'Lost Ray-Ban sunglasses at Sukhumvit Soi 11. Silver frame. Reward if found!',
        'imageUrl': 'https://images.unsplash.com/photo-1572635196237-14b3f281503f?q=80&w=600&auto=format&fit=crop', // Sunglasses
        'timeAgo': '3hours ago',
      },
    ];

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
                    ),
                    if (secondItemIndex < lostItems.length)
                      LostItemCard(
                        description: lostItems[secondItemIndex]['description']!,
                        imageUrl: lostItems[secondItemIndex]['imageUrl']!,
                        timeAgo: lostItems[secondItemIndex]['timeAgo']!,
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
