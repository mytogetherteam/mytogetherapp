import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/dio_error_message.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/location_display_util.dart';
import '../../../home/data/repositories/restaurant_repository.dart';
import '../models/user_location_model.dart';
import '../session_location_store.dart';

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

  bool get _isGuest => !AuthService().isLoggedIn;

  /// True when the user picked live GPS for this session (not a saved address).
  bool get isSessionCurrentLocation =>
      _activeLocation?.id == -1;

  void setActiveLocation(UserLocationModel location) {
    if (_activeLocation?.id == location.id &&
        _activeLocation?.latitude == location.latitude &&
        _activeLocation?.longitude == location.longitude &&
        _activeLocation?.address == location.address &&
        _activeLocation?.buildingName == location.buildingName) {
      return;
    }
    _activeLocation = location;
    RestaurantRepository.instance.clearNearbyCache();
    notifyListeners();
  }

  /// Clears saved-address cache and active selection after sign-out so guests
  /// fall back to device current location.
  void clearCachedLocationsForSignOut() {
    _cachedLocations = null;
    _activeLocation = null;
    RestaurantRepository.instance.clearNearbyCache();
    notifyListeners();
  }

  Future<List<UserLocationModel>> getRawLocations({bool forceRefresh = false}) async {
    if (_isGuest) return const [];

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
    if (_isGuest) {
      throw DioException(
        requestOptions: RequestOptions(path: _baseUrl),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 401,
          statusMessage: 'Login required to save addresses',
        ),
      );
    }
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
    if (_isGuest) {
      throw DioException(
        requestOptions: RequestOptions(path: '$_baseUrl/${location.id}'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 401,
        ),
      );
    }
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
    if (_isGuest) {
      throw DioException(
        requestOptions: RequestOptions(path: '$_baseUrl/$id'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 401,
        ),
      );
    }
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

  /// Sets the active location from device GPS when none is selected yet.
  /// Guests always browse with current location only (no saved addresses).
  Future<bool> ensureSessionCurrentLocationFromDevice({
    bool requestPermissionIfDenied = true,
  }) async {
    if (_activeLocation?.latitude != null && _activeLocation?.longitude != null) {
      return true;
    }

    try {
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: requestPermissionIfDenied,
        forceRefresh: true,
        highAccuracy: !kIsWeb,
      );
      if (!LocationService().hasRealPosition) return false;

      final result = await LocationSearchService.instance.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      final storedAddress = await SessionLocationStore.addressNear(
        pos.latitude,
        pos.longitude,
      );
      final resolvedAddress = LocationDisplayUtil.firstReadableAddress([
        result?.displayName,
        LocationService().currentAddress,
        storedAddress,
      ]);

      final lat = result?.lat ?? pos.latitude;
      final lon = result?.lon ?? pos.longitude;
      final address = resolvedAddress ?? result?.displayName ?? '';

      if (address.trim().isNotEmpty) {
        await SessionLocationStore.save(
          latitude: lat,
          longitude: lon,
          address: address.trim(),
        );
      }

      // Pass the best place name (condo / building / POI) as buildingName so
      // food_header.dart shows it at the top instead of falling back to the
      // district name ("แขวงคลองจั่น"). nominatim_geocoder._bestName() already
      // prioritises building/neighbourhood keys over road/district.
      final buildingNameForSession =
          (result?.name != null && result!.name.trim().isNotEmpty)
              ? result.name.trim()
              : null;


      setActiveLocation(
        UserLocationModel(
          id: -1,
          latitude: lat,
          longitude: lon,
          address: address.isNotEmpty ? address : null,
          buildingName: buildingNameForSession,
          locationType: 'OTHER',
          isPrimary: true,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Single source of truth for coordinates used by nearby/explore feeds.
  /// 1. Set Location: Uses user's selected delivery location (saved primary or manual pin).
  /// 2. Current Location: If no saved address exists, falls back to device GPS.
  /// 3. Default Location: If GPS is unavailable/denied, uses app default (Bangkok).
  Future<({double lat, double lon})> resolveActiveCoordinates() async {
    var active = _activeLocation;
    if (active?.latitude == null || active?.longitude == null) {
      if (!_isGuest) {
        try {
          active = await getPrimaryLocation();
        } catch (_) {
          // Network error or no saved locations — fall through.
        }
      }
      // If no saved primary location (guest or newly registered user), resolve device GPS
      if (active?.latitude == null || active?.longitude == null) {
        await ensureSessionCurrentLocationFromDevice(
          requestPermissionIfDenied: true,
        );
        active = _activeLocation;
      }
    }
    if (active?.latitude != null && active?.longitude != null) {
      return (lat: active!.latitude!, lon: active.longitude!);
    }
    try {
      final pos = await LocationService().getCurrentPosition(
        requestPermissionIfDenied: true,
        forceRefresh: true,
      );
      if (LocationService().hasRealPosition) {
        return (lat: pos.latitude, lon: pos.longitude);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('user_location_repository.dart: ignored error: $e');
    }
    return (
      lat: LocationService.defaultLat,
      lon: LocationService.defaultLon,
    );
  }

  Future<UserLocationModel?> getPrimaryLocation({bool forceRefresh = false}) async {
    if (_isGuest) return null;

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
