import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../widgets/notification_item_widget.dart';
import '../order_notification_navigation.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../../core/presentation/utils/paginated_list_controller.dart';
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
  late final PaginatedListController<NotificationModel> _pagination;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _pagination = PaginatedListController<NotificationModel>(
      pageSize: 20,
      initialPage: 0,
      itemKey: (item) => item.id,
      fetchPage: (page) async {
        final batch = await _repository.getNotifications(page: page, size: 20);
        return PaginatedPage(
          items: batch,
          hasMore: batch.length >= 20,
        );
      },
    )..addListener(_onPaginationChanged);
    _pagination.attachScrollController(_scrollController);
    _pagination.loadInitial().then((_) => _repository.getUnreadCount());
    AnnouncementRepository().getUnreadCount();
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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    await _pagination.refresh();
    _repository.getUnreadCount();
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
    final index = _pagination.items.indexWhere((n) => n.id == notification.id);
    if (index == -1) return;
    final original = _pagination.items[index];
    setState(() {
      _pagination.items[index] = _asRead(original);
    });

    final success = await _repository.markAsRead(notification.id);
    if (!success) {
      if (mounted) {
        final revertIndex =
            _pagination.items.indexWhere((n) => n.id == notification.id);
        if (revertIndex != -1) {
          setState(() => _pagination.items[revertIndex] = original);
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
    final previous = List<NotificationModel>.from(_pagination.items);
    setState(() {
      for (int i = 0; i < _pagination.items.length; i++) {
        if (!_pagination.items[i].read) {
          _pagination.items[i] = _asRead(_pagination.items[i]);
        }
      }
    });
    _repository.setUnreadCount(0);

    final success = await _repository.markAllAsRead();
    if (!success) {
      if (mounted) {
        setState(() {
          _pagination.items
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
    final notifications = _pagination.items;
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
              if (notifications.any((n) => !n.read))
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
                child: _pagination.isInitialLoading
                    ? const Center(child: CustomLoadingIndicator(size: 40))
                    : notifications.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _refreshNotifications,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: notifications.length +
                                  (_pagination.showFooter ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == notifications.length) {
                                  return PaginationListFooter(
                                    isLoading: _pagination.isLoadingMore,
                                    showEndMessage: !_pagination.hasMore,
                                  );
                                }
                                _pagination.onItemVisible(index);
                                final notification = notifications[index];
                                return NotificationItemWidget(
                                  notification: notification,
                                  onTap: () =>
                                      _handleNotificationTap(notification),
                                );
                              },
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
