import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import '../widgets/news_feed_item.dart';
import '../../data/models/news_item.dart';
import '../../data/repositories/news_repository.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import 'package:mytogetherapp/core/presentation/widgets/pagination_list_footer.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/widgets/notification_bell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/core/utils/navigation_controller.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late final PaginatedListController<NewsItem> _pagination;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pagination = PaginatedListController<NewsItem>(
      pageSize: 20,
      initialPage: 1,
      itemKey: (item) => item.id,
      fetchPage: _fetchPage,
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(_scrollController);
    _pagination.loadInitial();
    // Double-tap same bottom tab → scroll to top + refresh
    NavigationController.instance.tabScrollToTopRequest.addListener(
      _onScrollToTopRequested,
    );
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  void _onScrollToTopRequested() {
    if (NavigationController.instance.tabScrollToTopRequest.value != 3) return;
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
    _pagination.refresh();
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _scrollController.dispose();
    NavigationController.instance.tabScrollToTopRequest.removeListener(
      _onScrollToTopRequested,
    );
    super.dispose();
  }

  Future<PaginatedPage<NewsItem>> _fetchPage(int page) async {
    final feed = await NewsRepository.instance.fetchFeed(page: page);
    return PaginatedPage(
      items: feed.items.map(NewsItem.fromNewsArticle).toList(),
      hasMore: feed.page < feed.totalPages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final newsItems = _pagination.items;
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _pagination.refresh,
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
                        fontSize:
                            LocaleController.instance.language.code == 'mm'
                                ? 18
                                : 24,
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
            if (newsItems.isEmpty && _pagination.isInitialLoading)
              const SliverFillRemaining(
                child: Center(child: CustomLoadingIndicator(size: 40)),
              )
            else if (newsItems.isEmpty)
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
                  (context, index) {
                    _pagination.onItemVisible(index);
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: NewsFeedItem(item: newsItems[index]),
                      ),
                    );
                  },
                  childCount: newsItems.length,
                ),
              ),
            if (newsItems.isNotEmpty && _pagination.showFooter)
              SliverToBoxAdapter(
                child: PaginationListFooter(
                  isLoading: _pagination.isLoadingMore,
                  showEndMessage: !_pagination.hasMore,
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }
}
