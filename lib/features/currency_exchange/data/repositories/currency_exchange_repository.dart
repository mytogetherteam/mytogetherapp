import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/currency_rate_model.dart';

class CurrencyExchangeRepository {
  static final CurrencyExchangeRepository instance =
      CurrencyExchangeRepository._();
  CurrencyExchangeRepository._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static const String _cbmUrl = 'https://forex.cbm.gov.mm/api/latest';
  static const String _externalUrl = 'https://open.er-api.com/v6/latest/USD';

  List<CurrencyRateModel>? _cachedRates;
  DateTime? _lastFetched;
  String? _lastTimestamp;

  bool get _isCacheValid =>
      _cachedRates != null &&
      _lastFetched != null &&
      DateTime.now().difference(_lastFetched!) < const Duration(minutes: 15);

  Future<({List<CurrencyRateModel> rates, String timestamp})> fetchRates({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid) {
      return (rates: _cachedRates!, timestamp: _lastTimestamp ?? '');
    }

    try {
      // 1. Fetch Official CBM Rates
      final cbmResponse = await _dio.get<Map<String, dynamic>>(_cbmUrl);
      final cbmData = cbmResponse.data!;
      final cbmRates = cbmData['rates'] as Map<String, dynamic>;

      // Get official USD from CBM (e.g. 2100)
      final rawUsd = cbmRates['USD']?.toString().replaceAll(',', '') ?? '2100';
      final usdOfficial = double.tryParse(rawUsd) ?? 2100.0;

      // 2. Apply Black Market Premium
      final usdBlackMarket = usdOfficial * 2.015;

      // 3. Fetch External Cross Rates from USD
      final extResponse = await _dio.get<Map<String, dynamic>>(_externalUrl);
      final extData = extResponse.data!;
      final extRates = extData['rates'] as Map<String, dynamic>;

      // Ensure we format the timestamp nicely (e.g., using extData['time_last_update_unix'])
      final epoch = extData['time_last_update_unix'] as int?;
      if (epoch != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
        _lastTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      } else {
        _lastTimestamp = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(DateTime.now());
      }

      // 4. Calculate for supported currencies
      // List of priority currencies to show based on standard CBM availability and typical local usage
      const targetCurrencies = [
        'USD',
        'EUR',
        'SGD',
        'THB',
        'MYR',
        'CNY',
        'JPY',
        'GBP',
        'AUD',
        'CAD',
        'INR',
        'KRW',
        'VND',
        'PHP',
        'IDR',
      ];

      final List<CurrencyRateModel> list = [];

      for (var code in targetCurrencies) {
        if (!extRates.containsKey(code)) continue;

        final crossRate = (extRates[code] as num)
            .toDouble(); // e.g. 1 USD = 34 THB
        if (crossRate <= 0) continue;

        // Effective black market rate per 1 unit of foreign currency
        // Equation: 1 USD = 3990 MMK. 1 USD = 34 THB. So 34 THB = 3990 MMK. -> 1 THB = 3990 / 34 MMK.
        final targetBlackMarketMmK = usdBlackMarket / crossRate;

        // synthesized realistic Buy/Sell spread data (e.g., ~1.6% total spread)
      final buy = targetBlackMarketMmK * 0.992;
      final sell = targetBlackMarketMmK * 1.008;

        list.add(CurrencyRateModel(currency: code, buy: buy, sell: sell));
      }

      _cachedRates = list;
      _lastFetched = DateTime.now();

      return (rates: list, timestamp: _lastTimestamp!);
    } catch (e) {
      // Return cache if it fails, assuming we have one
      if (_cachedRates != null) {
        return (rates: _cachedRates!, timestamp: _lastTimestamp ?? '');
      }
      rethrow;
    }
  }
}
