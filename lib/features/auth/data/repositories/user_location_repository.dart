import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_location_model.dart';

class UserLocationRepository extends ChangeNotifier {
  static final UserLocationRepository instance = UserLocationRepository._internal();
  UserLocationRepository._internal();

  final Dio _dio = ApiClient().dio;
  static const String _baseUrl = '${ApiClient.apiPrefix}/user-locations';

  List<UserLocationModel>? _cachedLocations;
  UserLocationModel? _activeLocation;

  // HIGH-FIDELITY BKK MOCK DATA
  final List<UserLocationModel> _mockLocationsOriginal = [
    UserLocationModel(
      id: 999,
      latitude: 13.7445,
      longitude: 100.5562,
      locationName: 'Home',
      address: '15/1 Soi Sukhumvit 11, Watthana, Bangkok 10110',
      locationType: 'HOME',
      isPrimary: true,
    ),
    UserLocationModel(
      id: 998,
      latitude: 13.7214,
      longitude: 100.5288,
      locationName: 'Office',
      address: 'Empire Tower, South Sathon Rd, Yan Nawa, Bangkok 10120',
      locationType: 'OFFICE',
      isPrimary: false,
    ),
  ];

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
        
        if (locations.isEmpty) {
          locations = List.from(_mockLocationsOriginal);
        }
        
        _cachedLocations = locations;
        return locations;
      }
      return _cachedLocations ?? List.from(_mockLocationsOriginal);
    } catch (e) {
      if (_cachedLocations != null) return _cachedLocations!;
      // Fallback to mocks on error (API unreachable)
      _cachedLocations = List.from(_mockLocationsOriginal);
      return _cachedLocations!;
    }
  }

  Future<UserLocationModel> addLocation(UserLocationModel location) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: location.toJson()..remove('id'), // ID is assigned by backend
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final dynamic rawData = response.data;
        UserLocationModel saved;
        if (rawData is Map && rawData.containsKey('data')) {
          saved = UserLocationModel.fromJson(rawData['data']);
        } else {
          saved = UserLocationModel.fromJson(rawData);
        }
        _cachedLocations = null; // Clear cache on mutation
        notifyListeners();
        return saved;
      }
      throw Exception('Failed to add location');
    } catch (e) {
      // MOCK UPDATE: Allow adding brand new mock locations for simulation
      final newLoc = location.copyWith(id: DateTime.now().millisecondsSinceEpoch);
      if (newLoc.isPrimary) {
        _cachedLocations = _cachedLocations?.map((l) => l.copyWith(isPrimary: false)).toList();
      }
      _cachedLocations ??= [];
      _cachedLocations!.add(newLoc);
      notifyListeners();
      return newLoc;
    }
  }

  Future<UserLocationModel> updateLocation(UserLocationModel location) async {
    try {
      final response = await _dio.put(
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
        notifyListeners();
        return updated;
      }
      throw Exception('Failed to update location');
    } catch (e) {
      // MOCK UPDATE: Handle mock selection/updates
      if (_cachedLocations != null) {
        if (location.isPrimary) {
          _cachedLocations = _cachedLocations!.map((l) => l.copyWith(isPrimary: false)).toList();
        }
        final idx = _cachedLocations!.indexWhere((l) => l.id == location.id);
        if (idx != -1) {
          _cachedLocations![idx] = location;
        } else {
          _cachedLocations!.add(location);
        }
        notifyListeners();
        return location;
      }
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

  Future<UserLocationModel?> getPrimaryLocation({bool forceRefresh = false}) async {
    final locations = await getRawLocations(forceRefresh: forceRefresh);
    if (locations.isEmpty) return null;
    try {
      final loc = locations.firstWhere((loc) => loc.isPrimary);
      _activeLocation = loc;
      notifyListeners();
      return loc;
    } catch (_) {
      final loc = locations.isNotEmpty ? locations.first : null;
      _activeLocation = loc;
      notifyListeners();
      return loc;
    }
  }
}
