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
      // (Original implementation using Dio and CBM/ER-API removed)
      */
      throw Exception('API Disabled for Fallback Testing');
    } catch (e) {
      // Return cache if it fails, assuming we have one
      if (_cachedRates != null) {
        return (rates: _cachedRates!, timestamp: _lastTimestamp ?? '');
      }
      rethrow;
    }
  }
}
