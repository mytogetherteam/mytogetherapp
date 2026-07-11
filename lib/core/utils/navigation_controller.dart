import 'package:flutter/material.dart';

/// Global navigation controller so any screen can switch the root tab.
class NavigationController {
  NavigationController._();
  static final NavigationController instance = NavigationController._();

  /// Listen to this from MainNavigationScreen to switch tabs.
  final ValueNotifier<int?> tabChangeRequest = ValueNotifier(null);

  /// Fires with the tab index when the user taps an already-active tab.
  /// Each tab page listens to this and scrolls to top + refreshes its data.
  final ValueNotifier<int?> tabScrollToTopRequest = ValueNotifier(null);

  void goToTab(int index) {
    // Re-assign even when already on [index] so listeners still run after
    // navigation pops back to an existing [MainNavigationScreen].
    if (tabChangeRequest.value == index) {
      tabChangeRequest.value = null;
    }
    tabChangeRequest.value = index;
  }

  /// Called by MainNavigationScreen when the user taps the already-active tab.
  void triggerScrollToTop(int tabIndex) {
    // Toggle null → value so listeners fire even for repeated taps on the same tab.
    if (tabScrollToTopRequest.value == tabIndex) {
      tabScrollToTopRequest.value = null;
      // Post a micro-task so the null → value transition is seen by listeners.
      Future.microtask(() {
        tabScrollToTopRequest.value = tabIndex;
      });
    } else {
      tabScrollToTopRequest.value = tabIndex;
    }
  }

  // Food tab is index 1
  void goToFoodTab() => goToTab(1);

  // Home tab is index 0
  void goToHomeTab() => goToTab(0);
}
