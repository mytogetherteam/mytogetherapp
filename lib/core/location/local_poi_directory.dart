import 'dart:math';

import 'location_search_service.dart';

/// A curated local directory of popular condominiums, apartments, and residential
/// complexes in Thailand (especially expat/community hubs like Sukhumvit, Samrong, Bang Na).
///
/// Running searches against this directory costs $0.00 and requires 0 network requests.
class LocalPoi {
  final String name;
  final double lat;
  final double lon;
  final double radiusKm;
  final List<String> aliases;

  const LocalPoi({
    required this.name,
    required this.lat,
    required this.lon,
    this.radiusKm = 0.07, // 70 meters default radius
    this.aliases = const [],
  });
}

class LocalPoiDirectory {
  LocalPoiDirectory._();

  static const List<LocalPoi> pois = [
    // --- Samrong / Sukhumvit 113 / Sukhumvit 115 ---
    LocalPoi(
      name: 'LESTO CONDO Sukhumvit113',
      lat: 13.64714,
      lon: 100.60115,
      radiusKm: 0.12, // 120m covers all 4 towers (A, B, C, D) and clubhouse
      aliases: ['lesto condo', 'lesto', 'เลสโต คอนโด', 'เลสโต'],
    ),
    LocalPoi(
      name: 'Niche ID Sukhumvit 113',
      lat: 13.64725,
      lon: 100.60084,
      radiusKm: 0.08,
      aliases: ['niche id', 'นิช ไอดี', 'niche sukhumvit 113'],
    ),
    LocalPoi(
      name: 'The Metropolis Samrong Interchange',
      lat: 13.64520,
      lon: 100.59520,
      radiusKm: 0.09,
      aliases: ['metropolis samrong', 'เดอะ เมโทรโพลิส สำโรง'],
    ),
    LocalPoi(
      name: 'Ideo Sukhumvit 115',
      lat: 13.62770,
      lon: 100.59080,
      radiusKm: 0.08,
      aliases: ['ideo 115', 'ไอดีโอ สุขุมวิท 115'],
    ),
    LocalPoi(
      name: 'B-Loft Sukhumvit 115',
      lat: 13.62880,
      lon: 100.59250,
      radiusKm: 0.07,
      aliases: ['b loft 115', 'บีลอฟท์ 115'],
    ),
    LocalPoi(
      name: 'Lumpini Ville Sukhumvit 109 - Bearing',
      lat: 13.65580,
      lon: 100.59850,
      radiusKm: 0.08,
      aliases: ['lumpini 109', 'lumpini bearing', 'ลุมพินี วิลล์ สุขุมวิท 109'],
    ),
    LocalPoi(
      name: 'Notting Hill Sukhumvit 105',
      lat: 13.65820,
      lon: 100.61200,
      radiusKm: 0.08,
      aliases: ['notting hill 105', 'น็อตติ้ง ฮิลล์ สุขุมวิท 105'],
    ),
    LocalPoi(
      name: 'Unio Sukhumvit 72',
      lat: 13.66050,
      lon: 100.59880,
      radiusKm: 0.08,
      aliases: ['unio 72', 'ยูนิโอ สุขุมวิท 72'],
    ),

    // --- Bang Na / Bearing / Udom Suk ---
    LocalPoi(
      name: 'The Parkland Bangna',
      lat: 13.66550,
      lon: 100.64720,
      radiusKm: 0.09,
      aliases: ['parkland bangna', 'เดอะ พาร์คแลนด์ บางนา'],
    ),
    LocalPoi(
      name: 'City Home Sukhumvit',
      lat: 13.68410,
      lon: 100.60850,
      radiusKm: 0.08,
      aliases: ['city home', 'ซิตี้ โฮม สุขุมวิท'],
    ),
    LocalPoi(
      name: 'Whizdom Sukhumvit 64',
      lat: 13.68750,
      lon: 100.61020,
      radiusKm: 0.08,
      aliases: ['whizdom 64', 'วิสซ์ดอม สุขุมวิท 64'],
    ),

    // --- On Nut / Phra Khanong / Rama 9 ---
    LocalPoi(
      name: 'The Tree Sukhumvit 71 - Ekkamai',
      lat: 13.71450,
      lon: 100.59750,
      radiusKm: 0.08,
      aliases: ['the tree 71', 'เดอะ ทรี สุขุมวิท 71'],
    ),
    LocalPoi(
      name: 'Lumpini Ville Ramkhamhaeng 44',
      lat: 13.76100,
      lon: 100.63600,
      radiusKm: 0.08,
      aliases: ['lumpini ramkhamhaeng 44', 'ลุมพินี รามคำแหง 44'],
    ),
  ];

  /// Find the closest POI within its defined radius from [lat], [lon].
  /// Returns null if no known POI is nearby.
  static LocalPoi? findNearby(double lat, double lon) {
    LocalPoi? closest;
    double minDistance = double.infinity;

    for (final poi in pois) {
      final dist = PlaceResult.haversine(lat, lon, poi.lat, poi.lon);
      if (dist <= poi.radiusKm && dist < minDistance) {
        minDistance = dist;
        closest = poi;
      }
    }
    return closest;
  }

  /// Free local forward search for POIs matching [query].
  static List<PlaceResult> search(String query, {double? lat, double? lon}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final matches = <PlaceResult>[];
    for (final poi in pois) {
      final nameLower = poi.name.toLowerCase();
      final aliasMatch = poi.aliases.any((a) => a.toLowerCase().contains(q));

      if (nameLower.contains(q) || aliasMatch) {
        final dist = (lat != null && lon != null)
            ? PlaceResult.haversine(lat, lon, poi.lat, poi.lon)
            : null;

        matches.add(
          PlaceResult(
            placeId: 'local_poi_${poi.name.replaceAll(' ', '_')}',
            name: poi.name,
            displayName: poi.name,
            lat: poi.lat,
            lon: poi.lon,
            distanceKm: dist,
          ),
        );
      }
    }

    if (lat != null && lon != null) {
      matches.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    }

    return matches;
  }
}
