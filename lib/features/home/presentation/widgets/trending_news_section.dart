import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'news_card.dart';

import '../../data/fallback_data.dart';
import 'package:mytogetherapp/features/news/presentation/screens/news_detail_page.dart';
import 'package:mytogetherapp/features/news/data/models/news_item.dart';

class TrendingNewsSection extends StatefulWidget {
  const TrendingNewsSection({super.key});

  @override
  State<TrendingNewsSection> createState() => _TrendingNewsSectionState();
}

class _TrendingNewsSectionState extends State<TrendingNewsSection> {
  final PageController _pageController = PageController();

  void _navigateToDetail(Map<String, String> data) {
    // Map simplified fallback data to full NewsItem model
    final newsItem = NewsItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Mock ID
      authorName: data['source'] ?? 'Unknown Source',
      authorAvatar: 'https://i.pravatar.cc/150?u=${data['source'] ?? 'unknown'}', // Mock Avatar
      content: data['title'] ?? '',
      imageUrls: [data['imageUrl'] ?? ''],
      likesCount: 124, // Mock likes
      commentsCount: 18, // Mock comments
      timeAgo: data['timeAgo'] ?? 'Just now',
      isLiked: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailPage(item: newsItem),
      ),
    );
  }

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

            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 270,
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
                      onTap: () => _navigateToDetail(newsItems[firstItemIndex]),
                    ),
                    if (secondItemIndex < newsItems.length)
                      NewsCard(
                        title: newsItems[secondItemIndex]['title']!,
                        imageUrl: newsItems[secondItemIndex]['imageUrl']!,
                        source: newsItems[secondItemIndex]['source']!,
                        timeAgo: newsItems[secondItemIndex]['timeAgo']!,
                        onTap: () => _navigateToDetail(newsItems[secondItemIndex]),
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
