import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../widgets/notification_item_widget.dart';
import '../../../../core/presentation/widgets/custom_loading_indicator.dart';

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

    // --- MOCK DATA INJECTION ---
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate loading
    
    final List<NotificationModel> mockData = [
      NotificationModel(
        id: 1,
        title: 'Order Confirmed! 🍔',
        body: 'Your order from Lotteria has been confirmed and is being prepared.',
        type: 'ORDER',
        sentAt: DateTime.now().subtract(const Duration(minutes: 15)),
        read: false,
      ),
      NotificationModel(
        id: 2,
        title: 'Flash Sale! 🔥',
        body: 'Get 50% OFF on all pizza orders for the next 2 hours. Use code PIZZA50.',
        type: 'PROMO',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
        read: false,
      ),
      NotificationModel(
        id: 3,
        title: 'Welcome to MyTogether! 🎉',
        body: 'Start exploring the best local food and services right at your fingertips.',
        type: 'SYSTEM',
        sentAt: DateTime.now().subtract(const Duration(days: 1)),
        read: true,
      ),
      NotificationModel(
        id: 4,
        title: 'Delivery Update 🛵',
        body: 'Rider is picking up your order from The Pizza Company.',
        type: 'ORDER',
        sentAt: DateTime.now().subtract(const Duration(hours: 5)),
        read: true,
      ),
       NotificationModel(
        id: 5,
        title: 'Points Earned 💎',
        body: 'You just earned 50 loyalty points from your last purchase.',
        type: 'WALLET',
        sentAt: DateTime.now().subtract(const Duration(days: 2)),
        read: true,
      ),
    ];

    if (mounted) {
      setState(() {
        _notifications.clear();
        _notifications.addAll(mockData);
        _isLoading = false;
        _hasMore = false; // No pagination needed for mock
        _isLoadingMore = false;
      });
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
  }

  Future<void> _markAllAsRead() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Notifications',
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
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: _isLoading
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
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We will notify you when there is something new',
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
