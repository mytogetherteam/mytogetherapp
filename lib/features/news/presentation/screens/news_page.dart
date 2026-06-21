import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../widgets/news_feed_item.dart';
import '../../data/models/news_item.dart';
import '../../data/repositories/news_repository.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/notification_bell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final List<NewsItem> _newsItems = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
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
      if (!_isLoading && _hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _hasMore = true;
    });

    try {
      final feed = await NewsRepository.instance.fetchFeed(page: 1);
      if (mounted) {
        setState(() {
          _newsItems
            ..clear()
            ..addAll(feed.items.map(NewsItem.fromNewsArticle));
          _hasMore = feed.page < feed.totalPages;
          _page = 1;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadInitialData();
  }

  Future<void> _loadMoreData() async {
    if (!_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final nextPage = _page + 1;
      final feed = await NewsRepository.instance.fetchFeed(page: nextPage);
      if (mounted) {
        setState(() {
          _newsItems.addAll(feed.items.map(NewsItem.fromNewsArticle));
          _page = nextPage;
          _hasMore = feed.page < feed.totalPages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
              toolbarHeight: 48,
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/app_icon_small.png',
                    height: 28,
                  ),
                  const SizedBox(width: 12),
                  Transform.translate(
                    offset: const Offset(0, 4),
                    child: Text(
                      context.tr('nav.news'),
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: LocaleController.instance.language.code == 'mm' ? 18 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: NotificationBell(),
                ),
              ],
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  height: 1,
                ),
              ),
            ),
            if (_newsItems.isEmpty && _isLoading)
              const SliverFillRemaining(
                child: Center(child: CustomLoadingIndicator(size: 40)),
              )
            else if (_newsItems.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    context.tr('news.empty'),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => NewsFeedItem(item: _newsItems[index], showProfile: false),
                  childCount: _newsItems.length,
                ),
              ),
            if (_isLoading && _newsItems.isNotEmpty)
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
