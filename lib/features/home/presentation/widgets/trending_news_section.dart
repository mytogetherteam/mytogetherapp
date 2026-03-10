import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'news_card.dart';
import 'view_all_icon_button.dart';

class TrendingNewsSection extends StatefulWidget {
  const TrendingNewsSection({super.key});

  @override
  State<TrendingNewsSection> createState() => _TrendingNewsSectionState();
}

class _TrendingNewsSectionState extends State<TrendingNewsSection> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    // Dummy data for Trending News
    final List<Map<String, String>> newsItems = [
      {
        'title': 'The latest news, special news, world and Myanmar news, videos and audio news, articles from BBC...',
        'imageUrl': 'https://images.unsplash.com/photo-1504711432869-b39743a4be9a?q=80&w=600&auto=format&fit=crop',
        'source': 'BBC News',
        'timeAgo': '4min ago',
      },
      {
        'title': 'Lorem ipsum dolor sit amet consectetur. Pulvinar ut sed leo risus sit ut accumsan condimen...',
        'imageUrl': 'https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=600&auto=format&fit=crop',
        'source': 'The Guardian',
        'timeAgo': '10min ago',
      },
      {
        'title': 'Major breakthrough in renewable energy research announced by global scientific consortium...',
        'imageUrl': 'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?q=80&w=600&auto=format&fit=crop',
        'source': 'Reuters',
        'timeAgo': '15min ago',
      },
      {
        'title': 'Local community comes together to restore historic park in the heart of the city...',
        'imageUrl': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=600&auto=format&fit=crop',
        'source': 'City Times',
        'timeAgo': '1hour ago',
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
                'Trending News',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _pageController,
            itemCount: (newsItems.length / 2).ceil(),
            itemBuilder: (context, pageIndex) {
              final firstItemIndex = pageIndex * 2;
              final secondItemIndex = firstItemIndex + 1;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    NewsCard(
                      title: newsItems[firstItemIndex]['title']!,
                      imageUrl: newsItems[firstItemIndex]['imageUrl']!,
                      source: newsItems[firstItemIndex]['source']!,
                      timeAgo: newsItems[firstItemIndex]['timeAgo']!,
                    ),
                    if (secondItemIndex < newsItems.length)
                      NewsCard(
                        title: newsItems[secondItemIndex]['title']!,
                        imageUrl: newsItems[secondItemIndex]['imageUrl']!,
                        source: newsItems[secondItemIndex]['source']!,
                        timeAgo: newsItems[secondItemIndex]['timeAgo']!,
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
