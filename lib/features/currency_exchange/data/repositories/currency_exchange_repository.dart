import '../models/currency_rate_model.dart';

class CurrencyExchangeRepository {
  static final CurrencyExchangeRepository instance =
      CurrencyExchangeRepository._();
  CurrencyExchangeRepository._();

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
      /*
      // API calls disabled for fallback testing
      // (Original implementation removed for mockup stage)
      */
      throw Exception('API Disabled for Fallback Testing');
    } catch (e) {
      // Return high-quality mock data for development
      final mockRates = [
        const CurrencyRateModel(currency: 'THB', buy: 135.5, sell: 138.0),
        const CurrencyRateModel(currency: 'USD', buy: 4850.0, sell: 4950.0),
        const CurrencyRateModel(currency: 'SGD', buy: 3580.0, sell: 3650.0),
        const CurrencyRateModel(currency: 'MYR', buy: 1080.0, sell: 1120.0),
        const CurrencyRateModel(currency: 'JPY', buy: 31.2, sell: 33.5),
        const CurrencyRateModel(currency: 'GBP', buy: 6150.0, sell: 6300.0),
        const CurrencyRateModel(currency: 'VND', buy: 0.18, sell: 0.22),
      ];
      
      _cachedRates = mockRates;
      _lastFetched = DateTime.now();
      _lastTimestamp = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} Today';
      
      return (rates: _cachedRates!, timestamp: _lastTimestamp!);
    }
  }
}
