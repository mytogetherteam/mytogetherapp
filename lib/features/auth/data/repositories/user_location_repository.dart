import 'package:flutter/foundation.dart';
import '../models/user_location_model.dart';

class UserLocationRepository extends ChangeNotifier {
  static final UserLocationRepository instance = UserLocationRepository._internal();
  UserLocationRepository._internal();

  List<UserLocationModel>? _cachedLocations;
  UserLocationModel? _activeLocation;

  UserLocationModel? get activeLocation => _activeLocation;

  void setActiveLocation(UserLocationModel location) {
    if (_activeLocation?.id == location.id && 
        _activeLocation?.latitude == location.latitude && 
        _activeLocation?.longitude == location.longitude) {
      return;
    }
    _activeLocation = location;
    notifyListeners();
  }

  Future<List<UserLocationModel>> getRawLocations({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedLocations != null) {
      return _cachedLocations!;
    }

    // Bypass missing backend endpoint to prevent persistent 404 errors in console
    _cachedLocations = [];
    return [];
  }

  Future<UserLocationModel> addLocation(UserLocationModel location) async {
    // Bypass missing backend endpoint
    final saved = location.copyWith(id: DateTime.now().millisecondsSinceEpoch);
    _cachedLocations = null; // Clear cache on mutation
    notifyListeners();
    return saved;
  }

  Future<UserLocationModel> updateLocation(UserLocationModel location) async {
    // Bypass missing backend endpoint
    _cachedLocations = null; // Clear cache on mutation
    notifyListeners();
    return location;
  }

  Future<void> deleteLocation(int id) async {
    // Bypass missing backend endpoint
    _cachedLocations = null;
    notifyListeners();
  }

  Future<UserLocationModel?> getPrimaryLocation({bool forceRefresh = false}) async {
    final locations = await getRawLocations(forceRefresh: forceRefresh);
    if (locations.isEmpty) return null;
    try {
      final loc = locations.firstWhere((loc) => loc.isPrimary);
      _activeLocation = loc;
      return loc;
    } catch (_) {
      final loc = locations.first;
      _activeLocation = loc;
      return loc;
    }
  }
}
