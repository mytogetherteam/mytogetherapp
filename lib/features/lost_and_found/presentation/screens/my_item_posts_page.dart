import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import 'package:mytogetherapp/core/presentation/widgets/primary_gradient_button.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/models/item_post_dto.dart';
import '../../data/repositories/item_post_repository.dart';
import 'create_item_post_page.dart';

/// Lists the current user's own Lost & Found posts with edit/delete actions.
/// Backend: GET /api/user/item-posts/mine
class MyItemPostsPage extends StatefulWidget {
  const MyItemPostsPage({super.key});

  @override
  State<MyItemPostsPage> createState() => _MyItemPostsPageState();
}

class _MyItemPostsPageState extends State<MyItemPostsPage> {
  final List<ItemPostDto> _items = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  // Set when any edit/delete happens, so the parent feed can refresh on pop.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _hasMore = true;
    });
    try {
      final feed = await ItemPostRepository.instance.fetchMine(page: 1);
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(feed.items);
          _hasMore = feed.page < feed.totalPages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final nextPage = _page + 1;
      final feed = await ItemPostRepository.instance.fetchMine(page: nextPage);
      if (mounted) {
        setState(() {
          _items.addAll(feed.items);
          _page = nextPage;
          _hasMore = feed.page < feed.totalPages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editPost(ItemPostDto post) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateItemPostPage(existingPost: post),
      ),
    );
    if (updated == true) {
      _changed = true;
      await _loadInitial();
    }
  }

  Future<void> _createPost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateItemPostPage(),
      ),
    );
    if (created == true) {
      _changed = true;
      await _loadInitial();
    }
  }

  Future<void> _deletePost(ItemPostDto post) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.tr('lost.delete_title'),
      content: context.tr('lost.delete_confirm'),
      buttonText: context.tr('common.delete'),
      secondaryButtonText: context.tr('common.cancel'),
      showCloseIcon: false,
    );
    if (confirmed != true) return;

    try {
      await ItemPostRepository.instance.delete(post.id);
      _changed = true;
      if (mounted) {
        setState(() => _items.removeWhere((p) => p.id == post.id));
        AppDialog.showToast(context, context.tr('lost.deleted'));
      }
    } catch (_) {
      if (mounted) {
        AppDialog.showToast(
          context,
          context.tr('lost.delete_failed'),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: Text(
            context.tr('lost.my_posts'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadInitial,
          color: AppColors.primary,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _isLoading) {
      return const Center(child: CustomLoadingIndicator(size: 28));
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.travel_explore_rounded,
                    size: 56,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('lost.my_posts_empty'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('lost.my_posts_empty_sub'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryGradientButton(
                  onPressed: _createPost,
                  width: 260,
                  child: Text(
                    context.tr('lost.my_posts_empty_cta'),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _items.length + (_isLoading && _hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CustomLoadingIndicator(size: 24)),
          );
        }
        return _MyPostTile(
          post: _items[index],
          onEdit: () => _editPost(_items[index]),
          onDelete: () => _deletePost(_items[index]),
        );
      },
    );
  }
}

class _MyPostTile extends StatelessWidget {
  final ItemPostDto post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MyPostTile({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isFound = post.type.toUpperCase() == 'FOUND';
    final thumb = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: thumb != null
                ? CachedNetworkImage(fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                    imageUrl: thumb,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isFound ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.tr(isFound ? 'lost.badge_found' : 'lost.badge_lost'),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isFound ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.description,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  post.timeAgo,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(context.tr('common.edit')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  context.tr('common.delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      color: Colors.grey.shade100,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade300),
    );
  }
}

