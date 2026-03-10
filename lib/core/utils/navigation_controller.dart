import 'package:flutter/material.dart';

/// Global navigation controller so any screen can switch the root tab.
class NavigationController {
  NavigationController._();
  static final NavigationController instance = NavigationController._();

  /// Listen to this from MainNavigationScreen to switch tabs.
  final ValueNotifier<int?> tabChangeRequest = ValueNotifier(null);

  void goToTab(int index) {
    tabChangeRequest.value = index;
  }

  // Food tab is index 1
  void goToFoodTab() => goToTab(1);
}
