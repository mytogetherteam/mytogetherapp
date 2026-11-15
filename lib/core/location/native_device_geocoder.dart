import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import 'location_search_service.dart';

/// 100% Free Device Native Geocoder.
///
/// Uses Apple CoreLocation on iOS and Android System Geocoder on Android.
/// - Cost: $0.00 FREE FOREVER.
/// - Requires NO Google Cloud billing account or credit card.
/// - Unaffected by Google API price changes or quotas.
class NativeDeviceGeocoder {
  NativeDeviceGeocoder._();

  static final Geocoding _geocoding = Geocoding();

  static Future<PlaceResult?> reverseGeocode(double lat, double lon) async {
    if (kIsWeb) return null;

    try {
      final placemarks = await _geocoding
          .placemarkFromCoordinates(lat, lon)
          .timeout(const Duration(seconds: 4));

      if (placemarks.isEmpty) return null;

      final p = placemarks.first;

      // Extract meaningful short name
      String name = '';
      if (p.name != null &&
          p.name!.trim().isNotEmpty &&
          p.name!.trim() != p.postalCode?.trim()) {
        name = p.name!.trim();
      } else if (p.thoroughfare != null && p.thoroughfare!.trim().isNotEmpty) {
        name = p.thoroughfare!.trim();
      } else if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) {
        name = p.subLocality!.trim();
      }

      // Build formatted street address
      final parts = <String>[];
      void addPart(String? val) {
        final t = val?.trim();
        if (t != null && t.isNotEmpty && !parts.contains(t)) {
          parts.add(t);
        }
      }

      // Add street/road
      if (p.street != null && p.street!.trim().isNotEmpty) {
        addPart(p.street);
      } else {
        if (p.subThoroughfare != null && p.subThoroughfare!.trim().isNotEmpty) {
          addPart(p.subThoroughfare);
        }
        if (p.thoroughfare != null && p.thoroughfare!.trim().isNotEmpty) {
          addPart(p.thoroughfare);
        }
      }

      addPart(p.subLocality);
      addPart(p.locality);
      addPart(p.subAdministrativeArea);
      addPart(p.administrativeArea);
      addPart(p.postalCode);

      final formatted = parts.isNotEmpty
          ? parts.join(', ')
          : (p.country ?? '');

      if (formatted.isEmpty) return null;

      return PlaceResult(
        placeId: 'native_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}',
        name: name.isNotEmpty ? name : formatted.split(',').first.trim(),
        displayName: formatted,
        lat: lat,
        lon: lon,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NativeDeviceGeocoder error: $e');
      return null;
    }
  }
}
