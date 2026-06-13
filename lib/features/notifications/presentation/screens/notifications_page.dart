import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../widgets/notification_item_widget.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';
import '../../../announcements/presentation/screens/announcements_page.dart';
import '../../../announcements/data/repositories/announcement_repository.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationRepository _repository = NotificationRepository();
  final List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  bool _hasMore = true;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Keep the announcement (megaphone) badge in sync when this screen opens.
    AnnouncementRepository().getUnreadCount();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
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
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      _loadNotifications();
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.read) return;

    final success = await _repository.markAsRead(notification.id);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            type: notification.type,
            referenceId: notification.referenceId,
            imageUrl: notification.imageUrl,
            sentAt: notification.sentAt,
            readAt: DateTime.now(),
            read: true,
          );
        }
      });
      // Sync global badge with server
      _repository.getUnreadCount();
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final removed = notification;
    final index = _notifications.indexOf(notification);
    setState(() => _notifications.remove(notification));

    final ok = await _repository.deleteNotification(notification.id);
    if (!ok && mounted) {
      setState(() => _notifications.insert(index, removed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('notification.delete_failed'))),
      );
    } else {
      _repository.getUnreadCount();
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await _repository.markAllAsRead();
    if (success) {
      setState(() {
        for (int i = 0; i < _notifications.length; i++) {
          if (!_notifications[i].read) {
            _notifications[i] = NotificationModel(
              id: _notifications[i].id,
              title: _notifications[i].title,
              body: _notifications[i].body,
              type: _notifications[i].type,
              referenceId: _notifications[i].referenceId,
              imageUrl: _notifications[i].imageUrl,
              sentAt: _notifications[i].sentAt,
              readAt: DateTime.now(),
              read: true,
            );
          }
        }
      });
      // Sync global badge immediately
      _repository.getUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: context.tr('notification.tab_orders')),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(context.tr('notification.tab_announcements')),
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
                                if (scrollInfo.metrics.pixels ==
                                        scrollInfo.metrics.maxScrollExtent &&
                                    _hasMore) {
                                  _loadMore();
                                }
                                return true;
                              },
                              child: RefreshIndicator(
                                onRefresh: () => _loadNotifications(refresh: true),
                                child: ListView.builder(
                                  itemCount: _notifications.length + (_hasMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _notifications.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CustomLoadingIndicator(size: 24),
                                        ),
                                      );
                                    }
                                    final notification = _notifications[index];
                                    return NotificationItemWidget(
                                      notification: notification,
                                      onTap: () => _markAsRead(notification),
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
