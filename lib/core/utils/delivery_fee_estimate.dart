/// Distance-based delivery fee estimate shared by checkout and tracking.
///
/// Standard Bangkok Rider Market Rate:
/// Min ≈ Eco-rate (`20 + 8.0×km`), max ≈ Standard-rate (`28 + 9.2×km`).
class DeliveryFeeEstimate {
  DeliveryFeeEstimate._();

  static const double baseMin = 20.0;
  static const double perKmMin = 8.0;
  static const double baseMax = 28.0;
  static const double perKmMax = 9.2;
  static const double unrealKmCap = 100.0;
  static const double unrealKmFallback = 5.0;

  /// True for API/UI free-delivery labels (FREE / Free / localized "free").
  static bool isFreeLabel(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return false;
    final upper = t.toUpperCase();
    if (upper == 'FREE' || upper.contains('FREE')) return true;
    final lower = t.toLowerCase();
    if (lower == 'free') return true;
    // Localized common.free values (EN/MM/TH).
    if (lower == 'အခမဲ့' || lower == 'ฟรี') return true;
    return false;
  }

  /// Caps absurd OSRM/route distances (same rule as tracking).
  static double normalizeKm(double km) {
    if (km <= 0) return 0;
    return km > unrealKmCap ? unrealKmFallback : km;
  }

  static double minFee(double km) {
    final n = normalizeKm(km);
    if (n <= 0) return 0;
    return (baseMin + n * perKmMin).floorToDouble();
  }

  static double maxFee(double km) {
    final n = normalizeKm(km);
    if (n <= 0) return 0;
    return (baseMax + n * perKmMax).ceilToDouble();
  }

  /// Midpoint of min–max for a single cached fee when backend fee is absent.
  static double midFee(double km) {
    final min = minFee(km);
    final max = maxFee(km);
    if (min <= 0 && max <= 0) return 0;
    return ((min + max) / 2).roundToDouble();
  }

  /// Grab-style label: always the English promo word when free.
  static String rangeLabel(double km, {bool freeDelivery = false}) {
    if (freeDelivery) return 'FREE';
    final min = minFee(km);
    final max = maxFee(km);
    if (min <= 0 && max <= 0) return '฿ 0';
    final lo = min < max ? min : max;
    final hi = min > max ? min : max;
    if (lo == hi) {
      return '฿ ${lo.toStringAsFixed(0)} - ฿ ${(lo + 15).toStringAsFixed(0)}';
    }
    return '฿ ${lo.toStringAsFixed(0)} - ฿ ${hi.toStringAsFixed(0)}';
  }
}
