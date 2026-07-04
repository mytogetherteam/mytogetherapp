import 'package:intl/intl.dart';

/// Single source of truth for currency formatting across the app.
///
/// Thai Baht carries satang precision (Grab represents 25.50 baht), so every
/// monetary value is rendered with exactly two decimal places. Using one fixed
/// format guarantees that line items always sum up visually (e.g. 93.00 − 9.30
/// + 30.00 = 113.70) instead of mixing "84" with "83.7".
final NumberFormat _priceFormatter = NumberFormat('#,##0.00');

String _resolveCurrencySymbol(String currency) =>
    currency == 'THB' ? '฿' : currency;

extension PriceFormatting on num {
  String toFormattedPrice({String currency = '฿'}) {
    return '${_resolveCurrencySymbol(currency)} ${_priceFormatter.format(this)}';
  }
}

extension StringPriceFormatting on String {
  String toFormattedPrice({String currency = '฿'}) {
    final displayCurrency = _resolveCurrencySymbol(currency);

    // Try to parse the string directly first.
    final doubleValue = double.tryParse(this);
    if (doubleValue != null) {
      return '$displayCurrency ${_priceFormatter.format(doubleValue)}';
    }

    // Fallback: strip everything except digits and the decimal point.
    final cleanDigits = replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanDigits.isEmpty) return this;
    final value = double.tryParse(cleanDigits);
    if (value == null) return this;

    return '$displayCurrency ${_priceFormatter.format(value)}';
  }
}
