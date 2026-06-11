import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:mytogetherapp/core/presentation/widgets/custom_loading_indicator.dart';
import '../../data/models/announcement_model.dart';
import '../../data/repositories/announcement_repository.dart';
import '../widgets/announcement_detail_sheet.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final AnnouncementRepository _repository = AnnouncementRepository();
  final List<AnnouncementModel> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _items.clear();
        _isLoading = true;
        _hasMore = true;
      });
    }

    try {
      final fresh = await _repository.getAnnouncements(
        page: _currentPage,
        size: _pageSize,
      );
      setState(() {
        if (fresh.length < _pageSize) _hasMore = false;
        _items.addAll(fresh);
        _isLoading = false;
        _isLoadingMore = false;
      });
      _repository.getUnreadCount();
    } catch (_) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('announcement.load_failed'))),
        );
      }
    }
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      _load();
    }
  }

  void _openDetail(AnnouncementModel item) {
    AnnouncementDetailSheet.show(context, item);
    _markAsRead(item);
  }

  Future<void> _markAsRead(AnnouncementModel item) async {
    if (item.isRead) return;
    final ok = await _repository.markAsRead(item.id);
    if (ok && mounted) {
      setState(() {
        final i = _items.indexWhere((a) => a.id == item.id);
        if (i != -1) {
          _items[i] = _items[i].copyWith(isRead: true, readAt: DateTime.now());
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final ok = await _repository.markAllAsRead();
    if (ok && mounted) {
      setState(() {
        for (int i = 0; i < _items.length; i++) {
          if (!_items[i].isRead) {
            _items[i] = _items[i].copyWith(isRead: true, readAt: DateTime.now());
          }
        }
      });
    }
  }

  Future<void> _dismiss(AnnouncementModel item) async {
    final removed = item;
    final index = _items.indexOf(item);
    setState(() => _items.remove(item));
    final ok = await _repository.dismiss(item.id);
    if (!ok && mounted) {
      setState(() => _items.insert(index, removed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('announcement.dismiss_failed'))),
      );
    } else {
      _repository.getUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_items.any((a) => !a.isRead))
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextButton(
                  onPressed: _markAllAsRead,
                  child: Text(context.tr('announcement.mark_all_read')),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CustomLoadingIndicator(size: 40))
                : _items.isEmpty
                    ? _buildEmptyState()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          if (scrollInfo.metrics.pixels ==
                                  scrollInfo.metrics.maxScrollExtent &&
                              _hasMore) {
                            _loadMore();
                          }
                          return true;
                        },
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => _load(refresh: true),
                          child: ListView.builder(
                            itemCount: _items.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _items.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CustomLoadingIndicator(size: 24),
                                  ),
                                );
                              }
                              return _buildItem(_items[index]);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(AnnouncementModel item) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _dismiss(item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openDetail(item),
            child: Opacity(
              opacity: item.isRead ? 0.75 : 1.0,
              child: Container(
                height: 150,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildItemBackground(hasImage, item),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black87,
                          ],
                          stops: [0.25, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!item.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  _formatDate(item.createdAt),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemBackground(bool hasImage, AnnouncementModel item) {
    if (hasImage) {
      return CachedNetworkImage(
        imageUrl: item.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.primaryGradient)),
        errorWidget: (context, url, error) => _buildFallbackBackground(),
      );
    }
    return _buildFallbackBackground();
  }

  Widget _buildFallbackBackground() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            PhosphorIcons.megaphone,
            size: 56,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.megaphone,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('announcement.empty_title'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('announcement.empty_sub'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return context.relativeTime(date);
  }
}
