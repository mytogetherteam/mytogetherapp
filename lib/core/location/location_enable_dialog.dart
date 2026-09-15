import 'package:flutter/material.dart';
import 'package:mytogetherapp/core/localization/app_translations.dart';
import 'package:mytogetherapp/core/presentation/widgets/app_dialog.dart';

import 'location_service.dart';

/// Grab-style prompt when GPS is off or permission is denied.
/// Does not move the map; callers retry current-location after this returns.
class LocationEnableDialog {
  LocationEnableDialog._();

  static Future<bool> show(BuildContext context) async {
    final reason = LocationService().lastUnavailableReason;
    final serviceOff = reason == LocationUnavailableReason.serviceDisabled;
    final body = serviceOff
        ? context.tr('location.turn_on_body_gps')
        : context.tr('location.turn_on_body_permission');

    final shouldOpen = await AppDialog.show<bool>(
      context: context,
      title: context.tr('location.turn_on_title'),
      content: body,
      buttonText: context.tr('location.turn_on'),
      secondaryButtonText: context.tr('location.not_now'),
    );
    if (shouldOpen != true) return false;

    if (serviceOff) {
      await LocationService().openLocationSettings();
    } else {
      await LocationService().openAppSettings();
    }
    return true;
  }
}
