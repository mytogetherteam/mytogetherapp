import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/dio_error_message.dart';
import '../../../../core/location/location_service.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../models/user_location_model.dart';

class UserLocationRepository extends ChangeNotifier {
  static final UserLocationRepository instance = UserLocationRepository._internal();
  UserLocationRepository._internal();

  /// Mirrors `MAX_USER_LOCATIONS` in the NestJS backend.
  static const int maxSavedLocations = 3;

  static const String locationLimitMessage =
      'You can save at most 3 locations. Delete one before adding another.';

  final Dio _dio = ApiClient().dio;
  // Backend: UserLocationsController @Controller('user') with @Get('locations')
  static final String _baseUrl = '${ApiClient.apiPrefix}/user/locations';

  List<UserLocationModel>? _cachedLocations;
  UserLocationModel? _activeLocation;

  UserLocationModel? get activeLocation => _activeLocation;

  /// True when the user picked live GPS for this session (not a saved address).
  bool get isSessionCurrentLocation =>
      _activeLocation?.id == -1;

  void setActiveLocation(UserLocationModel location) {
    if (_activeLocation?.id == location.id &&
        _activeLocation?.latitude == location.latitude &&
        _activeLocation?.longitude == location.longitude) {
      return;
    }
    _activeLocation = location;
    RestaurantRepository.instance.clearNearbyCache();
    notifyListeners();
  }

  Future<List<UserLocationModel>> getRawLocations({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedLocations != null) {
      return _cachedLocations!;
    }

    try {
      final response = await _dio.get(_baseUrl);
      if (response.statusCode == 200 && response.data != null) {
        final dynamic rawData = response.data;
        List<UserLocationModel> locations = [];
        if (rawData is Map && rawData.containsKey('data')) {
          final List<dynamic> data = rawData['data'];
          locations = data.map((json) => UserLocationModel.fromJson(json)).toList();
        } else if (rawData is List) {
          locations = rawData.map((json) => UserLocationModel.fromJson(json)).toList();
        }
        _cachedLocations = locations;
        return locations;
      }
      return _cachedLocations ?? [];
    } catch (e) {
      if (_cachedLocations != null) return _cachedLocations!;
      rethrow;
    }
  }

  bool isAtLocationLimit(Iterable<UserLocationModel> locations) =>
      countSavedLocations(locations) >= maxSavedLocations;

  /// Only persisted backend addresses count toward the limit (not session GPS).
  int countSavedLocations(Iterable<UserLocationModel> locations) =>
      locations.where((l) => l.id > 0).length;

  Future<bool> canAddLocation() async {
    final locations = await getRawLocations();
    return !isAtLocationLimit(locations);
  }

  /// User-facing text for location create/update failures.
  static String errorMessage(Object error, {required String fallback}) {
    if (error is DioException && error.response?.statusCode == 409) {
      return dioErrorMessage(error, fallback: locationLimitMessage);
    }
    return dioErrorMessage(error, fallback: fallback);
  }

  Future<UserLocationModel> addLocation(UserLocationModel location) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: location.toJson()..remove('id'), // ID is assigned by backend
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final dynamic rawData = response.data;
        UserLocationModel saved;
        if (rawData is Map && rawData.containsKey('data')) {
          saved = UserLocationModel.fromJson(rawData['data']);
        } else {
          saved = UserLocationModel.fromJson(rawData);
        }
        _cachedLocations = null; // Clear cache on mutation
        if (saved.isPrimary) {
          _activeLocation = saved;
          RestaurantRepository.instance.clearNearbyCache();
        }
        notifyListeners();
        return saved;
      }
      throw Exception('Failed to add location');
    } on DioException {
      rethrow;
    }
  }

  Future<UserLocationModel> updateLocation(UserLocationModel location) async {
    try {
      // Backend uses PATCH /api/user/locations/:id (UserLocationsController).
      final response = await _dio.patch(
        '$_baseUrl/${location.id}',
        data: location.toJson(),
      );
      if (response.statusCode == 200 && response.data != null) {
        final dynamic rawData = response.data;
        UserLocationModel updated;
        if (rawData is Map && rawData.containsKey('data')) {
          updated = UserLocationModel.fromJson(rawData['data']);
        } else {
          updated = UserLocationModel.fromJson(rawData);
        }
        _cachedLocations = null; // Clear cache on mutation
        if (updated.isPrimary) {
          _activeLocation = updated;
          RestaurantRepository.instance.clearNearbyCache();
        }
        notifyListeners();
        return updated;
      }
      throw Exception('Failed to update location');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteLocation(int id) async {
    try {
      final response = await _dio.delete('$_baseUrl/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete location');
      }
      _cachedLocations = null; // Clear cache on mutation
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Single source of truth for coordinates used by nearby/explore feeds.
  /// Uses the user's selected delivery location only — never silently falls
  /// back to live device GPS (the user must tap "Current location" for that).
  Future<({double lat, double lon})> resolveActiveCoordinates() async {
    var active = _activeLocation;
    if (active?.latitude == null || active?.longitude == null) {
      try {
        active = await getPrimaryLocation();
      } catch (_) {
        // Not logged in / network error — fall through to default.
      }
    }
    if (active?.latitude != null && active?.longitude != null) {
      return (lat: active!.latitude!, lon: active.longitude!);
    }
    return (
      lat: LocationService.defaultLat,
      lon: LocationService.defaultLon,
    );
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
