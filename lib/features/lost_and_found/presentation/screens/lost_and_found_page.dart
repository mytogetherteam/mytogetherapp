import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../news/presentation/widgets/news_feed_item.dart';
import '../../../news/presentation/widgets/news_feed_item_skeleton.dart';
import '../../../news/data/models/news_item.dart';
import '../../../../../core/presentation/widgets/custom_loading_indicator.dart';

class LostAndFoundPage extends StatefulWidget {
  const LostAndFoundPage({super.key});

  @override
  State<LostAndFoundPage> createState() => _LostAndFoundPageState();
}

class _LostAndFoundPageState extends State<LostAndFoundPage> {
  final List<NewsItem> _items = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _items
          ..clear()
          ..addAll(_getMockData());
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _items
          ..clear()
          ..addAll(_getMockData());
      });
    }
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        final more = _getMockData().map((e) => NewsItem(
          id: '${_items.length + int.parse(e.id)}',
          authorName: e.authorName,
          authorAvatar: e.authorAvatar,
          content: e.content,
          imageUrls: e.imageUrls,
          likesCount: e.likesCount,
          commentsCount: e.commentsCount,
          timeAgo: 'Just now',
        )).toList();
        _items.addAll(more);
        _isLoading = false;
      });
    }
  }

  List<NewsItem> _getMockData() {
    return [
      NewsItem(
        id: '1',
        authorName: 'Aye Mya Thu',
        authorAvatar: 'https://i.pravatar.cc/150?img=47',
        location: 'MBK Center, Bangkok',
        rewardAmount: '฿500',
        content:
            'Black leather wallet near MBK Center, Bangkok. Contains ID card, credit cards, and some cash. If anyone found it please contact me urgently. Reward offered! 🙏',
        imageUrls: [
          'https://images.unsplash.com/photo-1627123424574-724758594e93?q=80&w=800&auto=format&fit=crop',
        ],
        likesCount: 312,
        commentsCount: 47,
        timeAgo: '5min ago',
        phoneNumber: '09791234567',
      ),
      NewsItem(
        id: '2',
        authorName: 'Ko Zaw Lin',
        authorAvatar: 'https://i.pravatar.cc/150?img=12',
        location: 'Lumphini Park',
        content:
            'A set of keys with a blue Toyota keychain found at Lumphini Park near the main gate. The owner can contact me to describe and claim. I will keep them safe until then.',
        imageUrls: [
          'https://images.unsplash.com/photo-1582139329536-e7284fece509?q=80&w=800&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?q=80&w=800&auto=format&fit=crop',
        ],
        likesCount: 198,
        commentsCount: 33,
        timeAgo: '20min ago',
        phoneNumber: '09792345678',
      ),
      NewsItem(
        id: '3',
        authorName: 'Ma Ei Phyu',
        authorAvatar: 'https://i.pravatar.cc/150?img=22',
        location: 'Asok Station',
        rewardAmount: '฿1000',
        content:
            'Black Adidas backpack left in the BTS Skytrain (Asok station) around 6:30 PM today. Contains a laptop, charger, and important documents. Please help me find it! 😭',
        imageUrls: [
          'https://images.unsplash.com/photo-1547949003-9792a18a2601?q=80&w=800&auto=format&fit=crop',
        ],
        likesCount: 482,
        commentsCount: 89,
        timeAgo: '1h ago',
        phoneNumber: '09793456789',
      ),
      NewsItem(
        id: '4',
        authorName: 'Min Khant Kyaw',
        authorAvatar: 'https://i.pravatar.cc/150?img=33',
        location: 'Chatuchak Market',
        content:
            'An iPhone 13 Pro with a transparent case found near Chatuchak Weekend Market. The phone is locked. If this is yours, please DM me with the lock screen wallpaper to verify ownership.',
        imageUrls: [
          'https://images.unsplash.com/photo-1632733711679-5292d6676184?q=80&w=800&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1512428813834-c294be702989?q=80&w=800&auto=format&fit=crop',
        ],
        likesCount: 720,
        commentsCount: 156,
        timeAgo: '2h ago',
        phoneNumber: '09794567890',
      ),
      NewsItem(
        id: '5',
        authorName: 'Su Myat Noe',
        authorAvatar: 'https://i.pravatar.cc/150?img=54',
        location: 'Sukhumvit Soi 11',
        rewardAmount: '฿300',
        content:
            'Ray-Ban Aviator sunglasses (gold frame, brown lens) lost somewhere between Sukhumvit Soi 11 and Asok. Last seen when I got out of a Grab car around noon. Very sentimental, please help! 🥺',
        imageUrls: [
          'https://images.unsplash.com/photo-1572635196237-14b3f281503f?q=80&w=800&auto=format&fit=crop',
        ],
        likesCount: 94,
        commentsCount: 12,
        timeAgo: '3h ago',
        phoneNumber: '09795678901',
      ),
      NewsItem(
        id: '6',
        authorName: 'Kyaw Zin Thant',
        authorAvatar: 'https://i.pravatar.cc/150?img=8',
        location: 'Siam Paragon',
        content:
            'A brown leather handbag left at Siam Paragon food court, Level B1. It has some cosmetics, a notebook, and a Thai ID inside. Please come to claim it at the security counter.',
        imageUrls: [
          'https://images.unsplash.com/photo-1584917865442-de89df76afd3?q=80&w=800&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?q=80&w=800&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?q=80&w=800&auto=format&fit=crop',
        ],
        likesCount: 536,
        commentsCount: 24,
        timeAgo: '4h ago',
        phoneNumber: '09796789012',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        edgeOffset: 60,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 52,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Lost & Found',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Colors.black.withOpacity(0.05),
                  height: 1,
                ),
              ),
            ),
            if (_items.isEmpty && _isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const NewsFeedItemSkeleton(),
                  childCount: 3,
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => NewsFeedItem(item: _items[index]),
                  childCount: _items.length,
                ),
              ),
            if (_isLoading && _items.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CustomLoadingIndicator(size: 24)),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }
}
