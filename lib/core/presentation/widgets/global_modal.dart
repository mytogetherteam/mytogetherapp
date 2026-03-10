import 'package:flutter/material.dart';

class GlobalModal {
  /// Displays a generic, globally styled modal dialog.
  /// This layout wraps any [Widget] child passed into it.
  static void show({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: barrierDismissible,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(36.0)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28.0, 36.0, 28.0, 28.0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
