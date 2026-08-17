import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:mytogetherapp/core/auth/auth_service.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/network/api_client.dart';
import 'package:mytogetherapp/core/utils/haptic_splash_factory.dart';
import 'package:mytogetherapp/features/auth/presentation/screens/profile_page.dart';

/// Opens [ProfilePage] (Order History, settings, etc.) via push — not a tab.
class ProfileAvatarButton extends StatelessWidget {
  final double size;
  final Color? borderColor;
  final Color? iconColor;
  final Color? backgroundColor;

  /// Light surfaces (Home / Food / News): darker border + icon.
  final bool onLightBackground;

  const ProfileAvatarButton({
    super.key,
    this.size = 36,
    this.borderColor,
    this.iconColor,
    this.backgroundColor,
    this.onLightBackground = false,
  });

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiClient.baseUrl}/$path';
  }

  void _openProfile(BuildContext context) {
    AppHaptics.buttonTap();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = GuestAuthGuard.isGuest;
    final user = AuthService().currentUser;
    final avatarUrl = _imageUrl(user?.avatarUrl);
    final radius = size / 2;
    final resolvedBorder = borderColor ??
        (onLightBackground
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.85));
    final resolvedIcon = iconColor ??
        (onLightBackground ? Colors.black54 : Colors.white);
    final resolvedBg = backgroundColor ??
        (onLightBackground
            ? Colors.grey.shade200
            : Colors.black.withValues(alpha: 0.35));

    return GestureDetector(
      onTap: () => _openProfile(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: resolvedBorder, width: 1.5),
          boxShadow: onLightBackground
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: resolvedBg,
          backgroundImage:
              !isGuest && avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
          child: isGuest || avatarUrl.isEmpty
              ? Icon(
                  isGuest ? PhosphorIcons.gearSix : PhosphorIcons.user,
                  size: size * 0.45,
                  color: resolvedIcon,
                )
              : null,
        ),
      ),
    );
  }
}
