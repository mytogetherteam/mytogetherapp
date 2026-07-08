import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../news/presentation/widgets/news_feed_item.dart';
import '../../../news/presentation/widgets/news_feed_item_skeleton.dart';
import '../../../news/data/models/news_item.dart';
import '../../data/repositories/item_post_repository.dart';
import 'package:mytogetherapp/core/presentation/utils/paginated_list_controller.dart';
import '../../../../../core/presentation/widgets/pagination_list_footer.dart';
import 'create_item_post_page.dart';
import 'my_item_posts_page.dart';

class LostAndFoundPage extends StatefulWidget {
  const LostAndFoundPage({super.key});

  @override
  State<LostAndFoundPage> createState() => _LostAndFoundPageState();
}

class _LostAndFoundPageState extends State<LostAndFoundPage> {
  late final PaginatedListController<NewsItem> _pagination;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pagination = PaginatedListController<NewsItem>(
      pageSize: 20,
      initialPage: 1,
      itemKey: (item) => item.id,
      fetchPage: (page) async {
        final feed = await ItemPostRepository.instance.fetchFeed(page: page);
        return PaginatedPage(
          items: feed.items.map(NewsItem.fromItemPost).toList(),
          hasMore: feed.page < feed.totalPages,
        );
      },
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(_scrollController);
    _pagination.loadInitial();
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_onPaginationChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateItemPostPage()),
    );
    if (created == true) {
      await _pagination.refresh();
    }
  }

  Future<void> _openMyPosts() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const MyItemPostsPage()),
    );
    if (changed == true) {
      await _pagination.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              toolbarHeight: 52,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 22,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Icon(
                        PhosphorIcons.magnifyingGlassFill,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('lost.title'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _openMyPosts,
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      context.tr('lost.my_posts'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  height: 1,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _openCreatePost,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[100],
                            child: Icon(PhosphorIcons.user, color: Colors.grey[400], size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                border: Border.all(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                context.tr('lost.create_title'),
                                style: GoogleFonts.notoSansMyanmar(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 6,
                    color: Colors.grey[100],
                  ),
                ],
              ),
            ),
            if (_pagination.items.isEmpty && _pagination.isInitialLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const NewsFeedItemSkeleton(),
                  childCount: 3,
                ),
              )
            else if (_pagination.items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    context.tr('lost.empty'),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    _pagination.onItemVisible(index);
                    return NewsFeedItem(
                      item: _pagination.items[index],
                      showBlockOption: true,
                    );
                  },
                  childCount: _pagination.items.length,
                ),
              ),
            if (_pagination.items.isNotEmpty && _pagination.showFooter)
              SliverToBoxAdapter(
                child: PaginationListFooter(
                  isLoading: _pagination.isLoadingMore,
                  showEndMessage: !_pagination.hasMore,
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}
