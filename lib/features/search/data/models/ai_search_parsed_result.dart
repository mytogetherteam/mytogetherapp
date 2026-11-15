class AiSearchParsedResult {
  final String search;
  final bool? isSpicy;
  final bool? isVegetarian;
  final bool? isHalal;
  final String? mealType;
  final bool? topRated;
  final String? intentLabel;

  const AiSearchParsedResult({
    required this.search,
    this.isSpicy,
    this.isVegetarian,
    this.isHalal,
    this.mealType,
    this.topRated,
    this.intentLabel,
  });

  bool get hasAnyFilter =>
      isSpicy != null ||
      isVegetarian == true ||
      isHalal == true ||
      (mealType != null && mealType!.isNotEmpty) ||
      topRated == true;

  factory AiSearchParsedResult.fromJson(Map<String, dynamic> json) {
    return AiSearchParsedResult(
      search: (json['search'] as String? ?? '').trim(),
      isSpicy: json['isSpicy'] as bool?,
      isVegetarian: json['isVegetarian'] as bool?,
      isHalal: json['isHalal'] as bool?,
      mealType: json['mealType'] as String?,
      topRated: json['topRated'] as bool?,
      intentLabel: json['intentLabel'] as String?,
    );
  }

  factory AiSearchParsedResult.fallback(String query) {
    return AiSearchParsedResult(search: query.trim());
  }
}

