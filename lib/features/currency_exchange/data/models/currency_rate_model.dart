class CurrencyRateModel {
  final String currency;
  final double buy;
  final double sell;

  const CurrencyRateModel({
    required this.currency,
    required this.buy,
    required this.sell,
  });

  factory CurrencyRateModel.fromJson(Map<String, dynamic> json) {
    return CurrencyRateModel(
      currency: json['currency'] as String,
      buy:
          double.tryParse(json['buy'].toString().replaceAll(',', '').trim()) ??
          0.0,
      sell:
          double.tryParse(json['sell'].toString().replaceAll(',', '').trim()) ??
          0.0,
    );
  }

  factory CurrencyRateModel.fromCbm(String currency, String rateStr) {
    final rate = double.tryParse(rateStr.replaceAll(',', '').trim()) ?? 0.0;
    return CurrencyRateModel(currency: currency, buy: rate, sell: rate);
  }

  String get flagEmoji {
    const flags = {
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'SGD': '🇸🇬',
      'MYR': '🇲🇾',
      'CNY': '🇨🇳',
      'THB': '🇹🇭',
      'JPY': '🇯🇵',
      'JPN': '🇯🇵',
      'GBP': '🇬🇧',
      'AUD': '🇦🇺',
      'CAD': '🇨🇦',
      'ILS': '🇮🇱',
      'SEK': '🇸🇪',
      'NOK': '🇳🇴',
      'DKK': '🇩🇰',
      'RUB': '🇷🇺',
      'KWD': '🇰🇼',
      'INR': '🇮🇳',
      'BND': '🇧🇳',
      'ZAR': '🇿🇦',
      'NPR': '🇳🇵',
      'CHF': '🇨🇭',
      'KES': '🇰🇪',
      'PKR': '🇵🇰',
      'EGP': '🇪🇬',
      'BDT': '🇧🇩',
      'SAR': '🇸🇦',
      'LAK': '🇱🇦',
      'KHR': '🇰🇭',
      'IDR': '🇮🇩',
      'LKR': '🇱🇰',
      'NZD': '🇳🇿',
      'CZK': '🇨🇿',
      'PHP': '🇵🇭',
      'KRW': '🇰🇷',
      'VND': '🇻🇳',
      'HKD': '🇭🇰',
      'BRL': '🇧🇷',
      'RSD': '🇷🇸',
    };
    return flags[currency] ?? '🏳️';
  }

  String get currencyName {
    const names = {
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'SGD': 'Singapore Dollar',
      'MYR': 'Malaysian Ringgit',
      'CNY': 'Chinese Yuan',
      'THB': 'Thai Baht',
      'JPY': 'Japanese Yen',
      'JPN': 'Japanese Yen',
      'GBP': 'British Pound',
      'AUD': 'Australian Dollar',
      'CAD': 'Canadian Dollar',
      'ILS': 'Israeli Shekel',
      'SEK': 'Swedish Krona',
      'NOK': 'Norwegian Krone',
      'DKK': 'Danish Krone',
      'RUB': 'Russian Ruble',
      'KWD': 'Kuwaiti Dinar',
      'INR': 'Indian Rupee',
      'BND': 'Brunei Dollar',
      'ZAR': 'South African Rand',
      'NPR': 'Nepalese Rupee',
      'CHF': 'Swiss Franc',
      'KES': 'Kenyan Shilling',
      'PKR': 'Pakistani Rupee',
      'EGP': 'Egyptian Pound',
      'BDT': 'Bangladeshi Taka',
      'SAR': 'Saudi Riyal',
      'LAK': 'Lao Kip',
      'KHR': 'Cambodian Riel',
      'IDR': 'Indonesian Rupiah',
      'LKR': 'Sri Lankan Rupee',
      'NZD': 'New Zealand Dollar',
      'CZK': 'Czech Koruna',
      'PHP': 'Philippine Peso',
      'KRW': 'South Korean Won',
      'VND': 'Vietnamese Dong',
      'HKD': 'Hong Kong Dollar',
      'BRL': 'Brazilian Real',
      'RSD': 'Serbian Dinar',
    };
    return names[currency] ?? currency;
  }

  double get midRate => (buy + sell) / 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyRateModel &&
          runtimeType == other.runtimeType &&
          currency == other.currency;

  @override
  int get hashCode => currency.hashCode;
}
