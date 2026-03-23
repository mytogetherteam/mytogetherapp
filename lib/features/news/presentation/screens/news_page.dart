import 'package:flutter/material.dart';
import '../widgets/news_feed_item.dart';
import '../../data/models/news_item.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final List<NewsItem> _newsItems = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _newsItems.clear();
        _newsItems.addAll(_getMockData());
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _newsItems.clear();
        _newsItems.addAll(_getMockData());
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    setState(() {
      _isLoading = true;
    });
    
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        // Appending mock data again for infinite scroll demo
        final moreData = _getMockData().map((e) => NewsItem(
          id: '${_newsItems.length + int.parse(e.id)}',
          authorName: e.authorName,
          authorAvatar: e.authorAvatar,
          content: '[More News] ${e.content}',
          imageUrls: e.imageUrls,
          likesCount: e.likesCount,
          commentsCount: e.commentsCount,
          timeAgo: 'Just now',
        )).toList();
        
        _newsItems.addAll(moreData);
        _isLoading = false;
      });
    }
  }

  List<NewsItem> _getMockData() {
    return [
      NewsItem(
        id: '1',
        authorName: 'BBC Burmese',
        authorAvatar: '',
        content:
            'နောက်ဆုံးရ သတင်း၊ အထူးသတင်း၊ ကမ္ဘာနဲ့ မြန်မာရေးရာ သတင်းတွေ၊ ဗီဒီယိုနဲ့ ရုပ်သံ သတင်းတွေ၊ ဆောင်းပါးတွေကို ဘီဘီစီမြန်မာပိုင်း စာမျက်နှာမှာ အချိန်နဲ့ တပြေးညီ ဖတ်ရှုနိုင်ပါတယ်။ မြန်မာနိုင်ငံရဲ့ နိုင်ငံရေး၊ စီးပွားရေးနဲ့ လူမှုရေး အခြေအနေတွေကို စုံစုံလင်လင် တင်ဆက်ပေးနေတာဖြစ်ပြီး နေ့စဉ်ဖြစ်ပေါ်နေတဲ့ ထူးခြားဖြစ်စဉ်တွေကိုလည်း မျက်ခြေမပြတ် စောင့်ကြည့်တင်ပြနေပါတယ်။ ကမ္ဘာတဝှမ်းက စိတ်ဝင်စားဖွယ် သတင်းတွေကိုလည်း မြန်မာဘာသာနဲ့ အလွယ်တကူ ဖတ်ရှုနိုင်မှာဖြစ်ပါတယ်။',
        imageUrls: [
          'https://images.unsplash.com/photo-1540914124281-342587941389?q=80&w=1000&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1000&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1488190211105-8b0e65b80b4e?q=80&w=1000&auto=format&fit=crop',
        ],
        likesCount: 6100,
        commentsCount: 123,
        timeAgo: '4min ago',
      ),
      NewsItem(
        id: '2',
        authorName: 'Together App',
        authorAvatar: '',
        content:
            'Exciting new features coming to Together App this month! Stay tuned for more updates on our upcoming releases and community events. We are working hard to bring you the best experience possible. Our team has been focusing on improving performance, adding highly requested features, and refining the overall user interface to make it more intuitive and beautiful. We can\'t wait to show you what we\'ve been building. Make sure to follow us on all social media platforms for the latest news and behind-the-scenes content.',
        imageUrls: [
          'https://images.unsplash.com/photo-1512428559083-a400a4b82c97?q=80&w=1000&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?q=80&w=1000&auto=format&fit=crop',
        ],
        likesCount: 3200,
        commentsCount: 45,
        timeAgo: '15min ago',
      ),
      NewsItem(
        id: '3',
        authorName: 'Travel Burma',
        authorAvatar: '',
        content:
            'Exploring the beauty of Inle Lake and its unique floating gardens. A must-visit destination in Myanmar for every traveler. The calm waters and the traditional leg-rowing fishermen provide a serene and authentic cultural experience. You can also visit many workshops showcasing traditional weaving, silver making, and cigar rolling. Don\'t forget to try the local Shan noodles at a lakeside restaurant during sunset for a truly magical moment. The area is also famous for its floating markets and beautiful pagodas that reflect on the clear water surface.',
        imageUrls: [
          'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1000&auto=format&fit=crop',
        ],
        likesCount: 8500,
        commentsCount: 231,
        timeAgo: '1h ago',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFED3973),
        edgeOffset: 60, // Start below the app bar
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 48,
              title: Image.asset(
                'assets/images/icon.png',
                height: 28,
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent, // Prevents tinting on scroll in M3
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Colors.black.withOpacity(0.05),
                  height: 1,
                ),
              ),
            ),
            if (_newsItems.isEmpty && _isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CustomLoadingIndicator(size: 40),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return NewsFeedItem(item: _newsItems[index]);
                  },
                  childCount: _newsItems.length,
                ),
              ),
            if (_isLoading && _newsItems.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CustomLoadingIndicator(size: 24),
                  ),
                ),
              ),
            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }
}
