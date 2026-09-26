/// Distance-based delivery fee estimate shared by checkout and tracking.
///
/// Min ≈ Bolt-style (`15 + 8.5×km`), max ≈ Grab-style (`35 + 7.2×km`).
class DeliveryFeeEstimate {
  DeliveryFeeEstimate._();

  static const double baseMin = 15.0;
  static const double perKmMin = 8.5;
  static const double baseMax = 35.0;
  static const double perKmMax = 7.2;
  static const double unrealKmCap = 100.0;
  static const double unrealKmFallback = 5.0;

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

  static String rangeLabel(double km, {bool freeDelivery = false}) {
    if (freeDelivery) return 'FREE';
    final min = minFee(km);
    final max = maxFee(km);
    if (min <= 0 && max <= 0) return '฿ 0';
    if (min == max) return '฿ ${min.toStringAsFixed(0)}';
    final lo = min < max ? min : max;
    final hi = min > max ? min : max;
    return '฿ ${lo.toStringAsFixed(0)} - ฿ ${hi.toStringAsFixed(0)}';
  }
}
