import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';
import 'package:mytogetherapp/features/cart/data/active_order_state.dart';

class LockScreenWidgetManager {
  static final LockScreenWidgetManager instance = LockScreenWidgetManager._internal();
  LockScreenWidgetManager._internal();

  final _liveActivitiesPlugin = LiveActivities();
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  String? _currentLiveActivityId;
  final int _notificationId = 8888;
  bool _isInitialized = false;

  String? _lastStatusText;
  int? _lastProgress;
  String? _lastShopName;

  bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }
    
    if (_isIOS) {
      try {
        await _liveActivitiesPlugin.init(
          appGroupId: 'group.com.mytogetherapp.orders', // Update with actual group ID if needed
        );
      } catch (e) {
        debugPrint('Live Activities init failed: $e');
      }
    } else if (_isAndroid) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
    }
    
    _isInitialized = true;
    
    // Add listener to keep native widgets in sync
    ActiveOrderState.instance.addListener(_onOrderStateChanged);
  }

  void _onOrderStateChanged() {
    final state = ActiveOrderState.instance;
    if (state.hasActiveOrder) {
      // Get the primary order
      final order = state.activeOrdersList.isNotEmpty ? state.activeOrdersList.first : null;
      if (order != null) {
        showOrUpdateWidget(order);
      }
    } else {
      hideWidget();
    }
  }

  Future<void> showOrUpdateWidget(ActiveOrderItem order) async {
    if (!_isInitialized) await initialize();

    final statusText = _getStatusText(order);
    final progress = _getProgressValue(order);
    final shopName = order.displayShopName;

    if (_lastStatusText == statusText && 
        _lastProgress == progress && 
        _lastShopName == shopName) {
      return; // No meaningful change, avoid spamming native widgets
    }

    _lastStatusText = statusText;
    _lastProgress = progress;
    _lastShopName = shopName;

    if (_isIOS) {
      final data = {
        'shopName': order.displayShopName,
        'statusText': statusText,
        'progress': progress,
      };

      try {
        if (_currentLiveActivityId == null) {
          _currentLiveActivityId = await _liveActivitiesPlugin.createActivity(
            'order_${order.orderId}',
            data,
          );
        } else {
          await _liveActivitiesPlugin.updateActivity(
            _currentLiveActivityId!,
            data,
          );
        }
      } catch (e) {
        debugPrint('Live Activities update failed: $e');
      }
    } else if (_isAndroid) {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'active_order_channel',
        'Active Orders',
        channelDescription: 'Shows the status of your active order',
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/launcher_icon',
        showProgress: true,
        maxProgress: 4,
        progress: progress,
        indeterminate: false,
        ongoing: true, // Keep it persistent while order is active
      );
      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        id: _notificationId,
        title: order.displayShopName.isNotEmpty ? order.displayShopName : 'Order Update',
        body: statusText,
        notificationDetails: platformChannelSpecifics,
      );
    }
  }

  Future<void> hideWidget() async {
    _lastStatusText = null;
    _lastProgress = null;
    _lastShopName = null;

    if (_isIOS && _currentLiveActivityId != null) {
      try {
        await _liveActivitiesPlugin.endActivity(_currentLiveActivityId!);
      } catch (_) {}
      _currentLiveActivityId = null;
    } else if (_isAndroid) {
      await _flutterLocalNotificationsPlugin.cancel(id: _notificationId);
    }
  }

  String _getStatusText(ActiveOrderItem order) {
    switch (order.orderStatus) {
      case 0:
        return 'Awaiting Confirmation';
      case 1:
        return order.showUploadSection ? 'Awaiting Payment' : 'Verifying Payment';
      case 2:
        return 'Preparing your order';
      case 3:
        return order.estimatedTime != null && order.estimatedTime!.isNotEmpty
            ? 'Est. Arrival: ${order.estimatedTime}'
            : 'On the way';
      case 4:
        return 'Delivered';
      default:
        return 'Processing';
    }
  }

  int _getProgressValue(ActiveOrderItem order) {
    return order.orderStatus.clamp(0, 4);
  }
}
