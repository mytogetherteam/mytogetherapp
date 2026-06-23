import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../../features/auth/presentation/screens/auth_entry_page.dart';
import '../localization/app_translations.dart';
import '../presentation/widgets/app_dialog.dart';

/// Helpers for guest-mode flows: prompt sign-in/register when a feature needs
/// an account, while the rest of the app remains browsable without login.
class GuestAuthGuard {
  GuestAuthGuard._();

  static bool get isGuest => !AuthService().isLoggedIn;

  /// Returns `true` when the caller may proceed (user is signed in).
  /// For guests, shows a dialog and offers navigation to [AuthEntryPage].
  static Future<bool> requireAccount(BuildContext context) async {
    if (!isGuest) return true;
    if (!context.mounted) return false;

    final shouldSignIn = await AppDialog.show<bool>(
      context: context,
      title: context.tr('guest.need_account_title'),
      content: context.tr('guest.need_account_message'),
      buttonText: context.tr('guest.create_or_login'),
      secondaryButtonText: context.tr('common.cancel'),
      onButtonPressed: () => Navigator.pop(context, true),
      onSecondaryPressed: () => Navigator.pop(context, false),
    );

    if (shouldSignIn == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthEntryPage()),
      );
    }
    return false;
  }

  /// Runs [action] only when signed in; otherwise prompts for an account.
  static Future<void> runIfSignedIn(
    BuildContext context,
    VoidCallback action,
  ) async {
    if (await requireAccount(context)) {
      action();
    }
  }

  /// Navigates to [page] when signed in; otherwise prompts for an account.
  static Future<void> pushIfSignedIn(
    BuildContext context,
    Widget page,
  ) async {
    if (!context.mounted) return;
    if (isGuest) {
      await requireAccount(context);
      return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
