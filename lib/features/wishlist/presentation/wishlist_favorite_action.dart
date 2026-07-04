import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/auth/guest_auth_guard.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';

import '../data/repositories/wishlist_repository.dart';
import 'screens/wishlist_page.dart';

/// The three kinds of items the wishlist can hold.
enum WishlistKind { menuItem, shop, place }

/// Centralizes the "favorite heart" behaviour shared by the reusable cards
/// (restaurant / menu item / place). Keeping the toggle and the saved-state
/// resolution in one place is what makes the heart stay in sync across every
/// screen: all cards read from and write to the single [WishlistRepository],
/// so toggling on one page is instantly reflected on all others.
class WishlistFavoriteAction {
  const WishlistFavoriteAction._();

  /// The effective saved state for [id]. Trusts the repository when it knows
  /// about the item (a confirmed row or an optimistic toggle); otherwise falls
  /// back to the feed-provided [fallback] flag so freshly loaded items render
  /// correctly before the wishlist is primed.
  static bool isSaved(WishlistKind kind, int id, bool fallback) {
    final repo = WishlistRepository.instance;
    switch (kind) {
      case WishlistKind.menuItem:
        return repo.knowsMenuItem(id) ? repo.isMenuItemSaved(id) : fallback;
      case WishlistKind.shop:
        return repo.knowsShop(id) ? repo.isShopSaved(id) : fallback;
      case WishlistKind.place:
        return repo.knowsPlace(id) ? repo.isPlaceSaved(id) : fallback;
    }
  }

  /// Toggles [id]'s saved state through the repository (optimistic + persisted)
  /// and, when [showToast] is true, surfaces a confirmation toast with a "View"
  /// shortcut to the matching wishlist tab. Errors are rolled back by the
  /// repository and surfaced as an error toast.
  static Future<void> toggle(
    BuildContext context,
    WishlistKind kind,
    int id, {
    required bool currentlySaved,
    bool showToast = true,
  }) async {
    if (!await GuestAuthGuard.requireAccount(context)) return;

    final willSave = !currentlySaved;
    final repo = WishlistRepository.instance;
    try {
      switch (kind) {
        case WishlistKind.menuItem:
          await repo.toggleMenuItem(id, willSave);
          break;
        case WishlistKind.shop:
          await repo.toggleShop(id, willSave);
          break;
        case WishlistKind.place:
          await repo.togglePlace(id, willSave);
          break;
      }
      if (showToast && context.mounted) {
        AppDialog.showToast(
          context,
          context.tr(willSave ? 'wishlist.saved' : 'wishlist.removed'),
          actionLabel: willSave ? context.tr('wishlist.view_action') : null,
          onAction: willSave
              ? () => WishlistPage.open(context, initialTab: _tabFor(kind))
              : null,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppDialog.showToast(
          context,
          context.tr('common.favorite_failed'),
          isError: true,
        );
      }
    }
  }

  static int _tabFor(WishlistKind kind) {
    switch (kind) {
      case WishlistKind.menuItem:
        return WishlistPage.tabMenuItems;
      case WishlistKind.shop:
        return WishlistPage.tabRestaurants;
      case WishlistKind.place:
        return WishlistPage.tabPlaces;
    }
  }
}
