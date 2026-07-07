import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../widgets/notification_item_widget.dart';
import '../order_notification_navigation.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/utils/pagination_scroll.dart';
import '../../../../core/presentation/widgets/pagination_list_footer.dart';
import '../../../announcements/presentation/screens/announcements_page.dart';
import '../../../announcements/data/repositories/announcement_repository.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  final NotificationRepository _repository = NotificationRepository();
  final ScrollController _scrollController = ScrollController();
  final List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  bool _hasMore = true;
  final int _pageSize = 20;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadNotifications();
    // Keep the announcement (megaphone) badge in sync when this screen opens.
    AnnouncementRepository().getUnreadCount();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool get _showPaginationFooter => _isLoadingMore || !_hasMore;

  Future<void> _loadNotifications({
    bool refresh = false,
    bool wasNearEnd = false,
  }) async {
    if (refresh) {
      setState(() {
        _currentPage = 0;
        _notifications.clear();
        _isLoading = true;
        _hasMore = true;
      });
    }

    try {
      final newNotifications = await _repository.getNotifications(
        page: _currentPage,
        size: _pageSize,
      );

      setState(() {
        if (newNotifications.length < _pageSize) {
          _hasMore = false;
        }
        _notifications.addAll(newNotifications);
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (!refresh) {
        PaginationScroll.maintainAfterPageAppend(
          _scrollController,
          wasNearEnd: wasNearEnd,
        );
      }
      
      // Sync unread count with server truth
      _repository.getUnreadCount();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('notification.load_failed'))),
        );
      }
    }
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      final wasNearEnd = PaginationScroll.wasNearEnd(_scrollController);
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      PaginationScroll.maintainAfterPageAppend(
        _scrollController,
        wasNearEnd: wasNearEnd,
      );
      _loadNotifications(wasNearEnd: wasNearEnd);
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    await _markAsRead(notification);

    if (!mounted) return;

    if (notification.isChatNotification) {
      await navigateToChatFromNotification(context, notification);
      return;
    }

    if (notification.isOrderNotification) {
      await navigateToOrderFromNotification(context, notification.referenceId!);
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.read) return;

    // Optimistic: flip to read immediately so the swipe-left animation plays
    // without waiting on the network. Revert if the request fails.
    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index == -1) return;
    final original = _notifications[index];
    setState(() {
      _notifications[index] = _asRead(original);
    });

    final success = await _repository.markAsRead(notification.id);
    if (!success) {
      if (mounted) {
        final revertIndex =
            _notifications.indexWhere((n) => n.id == notification.id);
        if (revertIndex != -1) {
          setState(() => _notifications[revertIndex] = original);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('notification.mark_read_failed'))),
        );
      }
      return;
    }
    // Sync global badge with server
    _repository.getUnreadCount();
  }

  /// Returns a copy of [n] flagged as read (NotificationModel is immutable).
  NotificationModel _asRead(NotificationModel n) {
    return NotificationModel(
      id: n.id,
      title: n.title,
      body: n.body,
      type: n.type,
      referenceId: n.referenceId,
      imageUrl: n.imageUrl,
      sentAt: n.sentAt,
      readAt: DateTime.now(),
      read: true,
    );
  }

  Future<void> _markAllAsRead() async {
    // Snapshot for rollback, then optimistically flip every unread item to read
    // so all rows animate (swipe-left) at once and the badge clears instantly.
    final previous = List<NotificationModel>.from(_notifications);
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].read) {
          _notifications[i] = _asRead(_notifications[i]);
        }
      }
    });
    _repository.setUnreadCount(0);

    final success = await _repository.markAllAsRead();
    if (!success) {
      if (mounted) {
        setState(() {
          _notifications
            ..clear()
            ..addAll(previous);
        });
        _repository.getUnreadCount();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('notification.mark_read_failed'))),
        );
      }
      return;
    }
    // Sync global badge with server truth
    _repository.getUnreadCount();
  }

  Widget _buildTabText(String text, int index) {
    if (_tabController.index == index) {
      return ShaderMask(
        shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Text(text),
      );
    } else {
      return Text(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          context.tr('notification.title'),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Handled by ShaderMask
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: [
            Tab(child: _buildTabText(context.tr('notification.tab_orders'), 0)),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabText(context.tr('notification.tab_announcements'), 1),
                  ValueListenableBuilder<int>(
                    valueListenable: AnnouncementRepository().unreadCount,
                    builder: (context, count, _) {
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 9 ? '9+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Orders
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_notifications.any((n) => !n.read))
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: TextButton(
                      onPressed: _markAllAsRead,
                      child: Text(context.tr('notification.mark_all_read')),
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CustomLoadingIndicator(size: 40))
                    : _notifications.isEmpty
                        ? _buildEmptyState()
                        : NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (scrollInfo.metrics.pixels >=
                                      scrollInfo.metrics.maxScrollExtent - 200 &&
                                  _hasMore &&
                                  !_isLoadingMore) {
                                _loadMore();
                              }
                              return false;
                            },
                            child: RefreshIndicator(
                              onRefresh: () => _loadNotifications(refresh: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _notifications.length +
                                    (_showPaginationFooter ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _notifications.length) {
                                    return PaginationListFooter(
                                      isLoading: _isLoadingMore,
                                      showEndMessage: !_hasMore,
                                    );
                                  }
                                  final notification = _notifications[index];
                                  return NotificationItemWidget(
                                    notification: notification,
                                    onTap: () => _handleNotificationTap(notification),
                                  );
                                },
                              ),
                            ),
                          ),
              ),
            ],
          ),
          
          // Tab 2: Announcements
          const AnnouncementsPage(),
        ],
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
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('notification.empty_title'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('notification.empty_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
