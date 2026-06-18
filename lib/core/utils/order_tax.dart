/// Order tax helpers — mirrors backend `order.constants.ts`.
class OrderTax {
  OrderTax._();

  static const double percent = 7;

  /// Tax = item subtotal × 7%, rounded to 2 decimal places.
  static double calculateTax(double itemSubtotal) {
    return (itemSubtotal * percent).round() / 100;
  }

  static double calculateTotal({
    required double itemSubtotal,
    double deliveryFee = 0,
  }) {
    return itemSubtotal + calculateTax(itemSubtotal) + deliveryFee;
  }
}
