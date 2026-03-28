import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'news_card.dart';
import 'view_all_icon_button.dart';
import '../../data/fallback_data.dart';

class TrendingNewsSection extends StatefulWidget {
  const TrendingNewsSection({super.key});

  @override
  State<TrendingNewsSection> createState() => _TrendingNewsSectionState();
}

class _TrendingNewsSectionState extends State<TrendingNewsSection> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    // Use high-quality fallback data
    final List<Map<String, String>> newsItems = FallbackData.news;

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
