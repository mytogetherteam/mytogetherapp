import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lost_item_card.dart';
import 'view_all_icon_button.dart';
import 'package:mytogetherapp/core/location/location_service.dart';
import 'package:mytogetherapp/features/lost_and_found/presentation/screens/lost_and_found_page.dart';
import 'package:mytogetherapp/features/lost_and_found/data/repositories/item_post_repository.dart';
import '../../../../features/news/data/models/news_item.dart';
import '../../../../features/news/presentation/screens/news_detail_page.dart';

class LostItemsNearbySection extends StatefulWidget {
  const LostItemsNearbySection({super.key});

  @override
  State<LostItemsNearbySection> createState() => _LostItemsNearbySectionState();
}

class _LostItemsNearbySectionState extends State<LostItemsNearbySection> {
  final PageController _pageController = PageController();
  List<NewsItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadNearby() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      final feed = await ItemPostRepository.instance.fetchNearby(
        latitude: pos.latitude,
        longitude: pos.longitude,
        page: 1,
        size: 10,
      );
      if (mounted) {
        setState(() {
          _items = feed.items.map(NewsItem.fromItemPost).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
        height: 250,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('home.lost_items_nearby'),
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
          height: 250,
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
                      child: LostItemCard(
                        description: _items[firstItemIndex].content,
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
                        child: LostItemCard(
                          description: _items[secondItemIndex].content,
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
