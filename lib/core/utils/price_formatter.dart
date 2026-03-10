import 'package:intl/intl.dart';

extension PriceFormatting on num {
  String toFormattedPrice({String currency = '฿'}) {
    final displayCurrency = currency == 'THB' ? '฿' : currency;
    final formatter = NumberFormat('#,###');
    return '$displayCurrency ${formatter.format(this)}';
  }
}

extension StringPriceFormatting on String {
  String toFormattedPrice({String currency = '฿'}) {
    final displayCurrency = currency == 'THB' ? '฿' : currency;
    
    // Try to parse the string directly first
    final doubleValue = double.tryParse(this);
    if (doubleValue != null) {
      final formatter = NumberFormat(doubleValue == doubleValue.toInt() ? '#,###' : '#,###.##');
      return '$displayCurrency ${formatter.format(doubleValue)}';
    }

    // Fallback: strip everything except digits and the decimal point
    final cleanDigits = replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanDigits.isEmpty) return this;
    final value = double.tryParse(cleanDigits);
    if (value == null) return this;
    
    final formatter = NumberFormat(value == value.toInt() ? '#,###' : '#,###.##');
    return '$displayCurrency ${formatter.format(value)}';
  }
}
