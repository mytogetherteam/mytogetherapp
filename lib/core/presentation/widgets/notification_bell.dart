import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../auth/guest_auth_guard.dart';
import '../../theme/app_colors.dart';
import '../../../features/auth/presentation/screens/auth_entry_page.dart';
import '../../../features/notifications/data/repositories/notification_repository.dart';
import '../../../features/notifications/presentation/screens/notifications_page.dart';

class NotificationBell extends StatelessWidget {
  final bool hasShadow;
  const NotificationBell({super.key, this.hasShadow = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationRepository().unreadCount,
      builder: (context, count, _) {
        return GestureDetector(
          onTap: () {
            if (GuestAuthGuard.isGuest) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthEntryPage()),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsPage(),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: hasShadow
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: const Icon(
                  PhosphorIcons.bell,
                  size: 24,
                  color: Colors.black,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -2,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
