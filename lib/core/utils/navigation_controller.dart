import 'package:flutter/material.dart';

/// Global navigation controller so any screen can switch the root tab.
class NavigationController {
  NavigationController._();
  static final NavigationController instance = NavigationController._();

  /// Listen to this from MainNavigationScreen to switch tabs.
  final ValueNotifier<int?> tabChangeRequest = ValueNotifier(null);

  void goToTab(int index) {
    // Re-assign even when already on [index] so listeners still run after
    // navigation pops back to an existing [MainNavigationScreen].
    if (tabChangeRequest.value == index) {
      tabChangeRequest.value = null;
    }
    tabChangeRequest.value = index;
  }

  // Food tab is index 1
  void goToFoodTab() => goToTab(1);

  // Home tab is index 0
  void goToHomeTab() => goToTab(0);
}
