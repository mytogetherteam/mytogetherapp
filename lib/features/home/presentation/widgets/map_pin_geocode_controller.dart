import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/location/location_display_util.dart';
import '../../../../core/location/location_search_service.dart';
import '../../../auth/data/session_location_store.dart';

/// Handles address lookup for map pin screens. Geocodes only after the pin
/// stops moving — never while the user is dragging the map.
class MapPinGeocodeController extends ChangeNotifier {
  MapPinGeocodeController({required this.addressController});

  final TextEditingController addressController;

  Timer? _geocodeDebounce;
  int _geocodeGeneration = 0;

  LatLng? _lastGeocodedPosition;
  PlaceResult? selectedPlace;
  bool isGeocoding = false;
  bool isMapMoving = false;
  bool addressTouched = false;
  String? addressError;

  static const _idleDebounce = Duration(milliseconds: 700);
  static const _minGeocodeDistanceMeters = 20.0;

  PlaceResult? get selectedPlaceResult => selectedPlace;

  /// Prefill from local cache only — no network call.
  Future<void> prefillFromCache(double lat, double lon) async {
    if (addressTouched) return;

    final stored = await SessionLocationStore.addressNear(lat, lon);
    final readable = LocationDisplayUtil.readableAddress(stored);
    if (readable != null && !addressTouched) {
      _applyAddress(readable, LatLng(lat, lon), place: selectedPlace);
    }
  }

  /// Look up address for the initial pin position (runs once on screen open).
  Future<void> lookupInitialPosition(LatLng target) async {
    if (addressTouched || addressController.text.trim().isNotEmpty) return;
    await _reverseGeocode(target, force: true);
  }

  void onAddressEdited() {
    addressTouched = true;
    if (addressController.text.trim().isNotEmpty) {
      addressError = null;
    }
    notifyListeners();
  }

  void applySearchResult(PlaceResult place) {
    selectedPlace = place;
    if (place.displayName.trim().isNotEmpty && !addressTouched) {
      addressController.text = place.displayName.trim();
      notifyListeners();
    }
  }

  void setAddressRequiredError(String message) {
    addressError = message;
    notifyListeners();
  }

  void onCameraMoveStarted() {
    _geocodeDebounce?.cancel();
    if (!isMapMoving) {
      isMapMoving = true;
      notifyListeners();
    }
  }

  void onPinDropped(LatLng target) {
    isMapMoving = false;
    notifyListeners();
    _scheduleGeocodeAfterDrop(target);
  }

  void _scheduleGeocodeAfterDrop(LatLng target, {bool force = false}) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(_idleDebounce, () {
      _reverseGeocode(target, force: force);
    });
  }

  Future<void> reverseGeocodeNow(LatLng target) async {
    _geocodeDebounce?.cancel();
    await _reverseGeocode(target, force: true);
  }

  Future<void> _reverseGeocode(LatLng target, {bool force = false}) async {
    if (isMapMoving) return;
    if (!force && !_shouldGeocode(target)) return;

    final generation = ++_geocodeGeneration;
    isGeocoding = true;
    notifyListeners();

    PlaceResult? place;
    var stillCurrent = true;
    try {
      place = await LocationSearchService.instance
          .reverseGeocode(target.latitude, target.longitude)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      place = null;
    }

    stillCurrent = generation == _geocodeGeneration && !isMapMoving;
    if (!stillCurrent) return;

    isGeocoding = false;
    if (place != null && !addressTouched) {
      _applyAddress(
        LocationDisplayUtil.readableAddress(place.displayName) ??
            place.displayName,
        target,
        place: place,
      );
    } else {
      notifyListeners();
    }
  }

  void _applyAddress(String address, LatLng target, {PlaceResult? place}) {
    selectedPlace = place ?? selectedPlace;
    _lastGeocodedPosition = target;
    addressController.text = address;
    notifyListeners();
  }

  bool _shouldGeocode(LatLng target) {
    if (_lastGeocodedPosition == null) return true;
    return _distanceMeters(_lastGeocodedPosition!, target) >=
        _minGeocodeDistanceMeters;
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }
}
