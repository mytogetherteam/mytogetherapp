import 'package:flutter/material.dart';
import '../../features/auth/data/repositories/user_location_repository.dart';

/// Notifies geo-scoped widgets (nearby shops, discount deals, etc.) when the
/// user picks a new delivery location. Do not use on global sections such as
/// collections, trending rankings, or promotions.
mixin LocationRefreshMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    UserLocationRepository.instance.addListener(_onActiveLocationChanged);
  }

  @override
  void dispose() {
    UserLocationRepository.instance.removeListener(_onActiveLocationChanged);
    super.dispose();
  }

  void _onActiveLocationChanged() {
    if (!mounted) return;
    onActiveLocationChanged();
  }

  void onActiveLocationChanged();
}
