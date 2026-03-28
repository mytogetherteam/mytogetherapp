import 'package:shared_preferences/shared_preferences.dart';

class SearchStorage {
  static const String _recentSearchesKey = 'recent_food_searches';
  static const int _maxRecentSearches = 10;

  static final SearchStorage _instance = SearchStorage._internal();
  factory SearchStorage() => _instance;
  SearchStorage._internal();

  List<String> _cachedSearches = [];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _loadFromDisk();
    _initialized = true;
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (_) {
      _cachedSearches = [];
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _cachedSearches);
    } catch (_) {}
  }

  List<String> get recentSearches => List.unmodifiable(_cachedSearches);

  bool get hasRecentSearches => _cachedSearches.isNotEmpty;

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;

    final trimmed = query.trim();

    _cachedSearches.remove(trimmed);
    _cachedSearches.insert(0, trimmed);

    if (_cachedSearches.length > _maxRecentSearches) {
      _cachedSearches = _cachedSearches.take(_maxRecentSearches).toList();
    }

    await _saveToDisk();
  }

  Future<void> removeSearch(String query) async {
    _cachedSearches.remove(query);
    await _saveToDisk();
  }

  Future<void> clearAll() async {
    _cachedSearches.clear();
    await _saveToDisk();
  }
}
