import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/locale_controller.dart';
import 'package:mytogetherapp/core/theme/app_colors.dart';
import '../../data/models/notification_model.dart';

class NotificationItemWidget extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationItemWidget({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: notification.read ? Colors.transparent : Colors.blue.withAlpha(20),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(notification.sentAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'ORDER_STATUS':
        iconData = Icons.shopping_bag_outlined;
        iconColor = Colors.orange;
        break;
      case 'PROMOTION':
        iconData = Icons.local_offer_outlined;
        iconColor = Colors.red;
        break;
      case 'SYSTEM':
      case 'ADMIN':
        iconData = Icons.notifications_none_outlined;
        iconColor = AppColors.primary; // Main pink for admin
        break;
      default:
        iconData = Icons.notifications_none_outlined;
        iconColor = Colors.grey;
    }

    bool isLogo = notification.type == 'SYSTEM' || notification.type == 'ADMIN';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(30),
        shape: BoxShape.circle,
      ),
      child: isLogo
          ? Image.asset(
              'assets/images/app_icon_small.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                iconData,
                color: iconColor,
                size: 20,
              ),
            )
          : Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
    );
  }

  String _formatDate(DateTime date) {
    return LocaleController.instance.relativeTime(date);
  }
}
