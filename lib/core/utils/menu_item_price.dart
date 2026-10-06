/// Mirrors backend `effectiveMenuItemPrice` / cart variant resolution.
double effectiveMenuItemPrice({
  required double originalPrice,
  double? discountAmount,
  double? discountPercentage,
}) {
  final base = originalPrice;
  if (discountAmount != null && discountAmount > 0) {
    final discounted = base - discountAmount;
    return discounted > 0 ? discounted : base;
  }
  if (discountPercentage != null && discountPercentage > 0) {
    final discounted = base * (1 - discountPercentage / 100);
    return discounted < 0 ? 0 : discounted;
  }
  return base;
}

/// Highest absolute variant (with menu discount) + other selected list prices as surcharges.
/// All-free selections return null so the caller keeps the menu base.
double? resolveSelectedVariantsListPrice({
  required List<double> selectedPrices,
  required double menuOriginalPrice,
  double? discountAmount,
  double? discountPercentage,
}) {
  if (selectedPrices.isEmpty) return null;
  final prices = selectedPrices.map((p) => p).toList();
  var maxPrice = 0.0;
  var maxIndex = 0;
  for (var i = 0; i < prices.length; i++) {
    if (prices[i] > maxPrice) {
      maxPrice = prices[i];
      maxIndex = i;
    }
  }
  if (!(maxPrice > 0)) return 0;

  var surcharges = 0.0;
  for (var i = 0; i < prices.length; i++) {
    if (i != maxIndex) surcharges += prices[i];
  }

  final discountedPrimary = effectiveMenuItemPrice(
    originalPrice: maxPrice,
    discountAmount: discountAmount,
    discountPercentage: discountPercentage,
  );
  return discountedPrimary + surcharges;
}
