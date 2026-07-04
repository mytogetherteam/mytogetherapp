import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'news_card.dart';
import 'view_all_icon_button.dart';
import '../../../../features/news/presentation/screens/news_page.dart';
import '../../../../features/news/data/models/news_item.dart';
import '../../../../features/news/data/repositories/news_repository.dart';
import '../../../../features/news/presentation/screens/news_detail_page.dart';

class TrendingNewsSection extends StatefulWidget {
  const TrendingNewsSection({super.key});

  @override
  State<TrendingNewsSection> createState() => _TrendingNewsSectionState();
}

class _TrendingNewsSectionState extends State<TrendingNewsSection> {
  final PageController _pageController = PageController();
  List<NewsItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    try {
      final feed = await NewsRepository.instance.fetchFeed(page: 1, size: 10);
      if (mounted) {
        setState(() {
          _items = feed.items.map(NewsItem.fromNewsArticle).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// First line of the post becomes the headline; the remaining text is the
  /// preview description (empty when the post is a single line).
  String _headline(String content) => content.split('\n').first.trim();

  String _summary(String content) {
    final lines = content.split('\n');
    if (lines.length <= 1) return '';
    return lines.sublist(1).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _navigateToDetail(NewsItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewsDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('home.trending_news'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              ViewAllIconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewsPage()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: (_items.length / 2).ceil(),
            itemBuilder: (context, pageIndex) {
              final firstItemIndex = pageIndex * 2;
              final secondItemIndex = firstItemIndex + 1;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: NewsCard(
                        title: _headline(_items[firstItemIndex].content),
                        description: _summary(_items[firstItemIndex].content),
                        source: _items[firstItemIndex].authorName,
                        imageUrl: _items[firstItemIndex].imageUrls.isNotEmpty
                            ? _items[firstItemIndex].imageUrls.first
                            : '',
                        timeAgo: _items[firstItemIndex].timeAgo,
                        onTap: () => _navigateToDetail(_items[firstItemIndex]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (secondItemIndex < _items.length)
                      Expanded(
                        child: NewsCard(
                          title: _headline(_items[secondItemIndex].content),
                          description: _summary(_items[secondItemIndex].content),
                          source: _items[secondItemIndex].authorName,
                          imageUrl:
                              _items[secondItemIndex].imageUrls.isNotEmpty
                                  ? _items[secondItemIndex].imageUrls.first
                                  : '',
                          timeAgo: _items[secondItemIndex].timeAgo,
                          onTap: () =>
                              _navigateToDetail(_items[secondItemIndex]),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
