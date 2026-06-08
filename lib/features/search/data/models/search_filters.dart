/// User-selectable filters for `GET /api/user/search`.
///
/// Mirrors the query parameters supported by the backend
/// (`UserSearchController.search`): dietary flags, a top-rated toggle, and
/// category / cuisine selectors.
class SearchFilters {
  final bool isVegetarian;
  final bool isHalal;
  final bool isSpicy;
  final bool topRated;

  /// Minimum average rating (e.g. 4.0 means "4.0 & up"). When set, the
  /// Rating filter chip is considered active.
  ///
  /// NOTE: The backend `GET /api/user/search` only supports a `topRated`
  /// boolean (ratingAvg >= 4.5), not an arbitrary threshold, so this value is
  /// applied client-side to the returned results rather than sent as a query
  /// parameter.
  final double? minRating;
  final int? categoryId;
  final int? subCategoryId;
  final int? masterCategoryId;
  final List<int> cuisineTypeIds;
  final List<String> mealTypes;
  final List<int> tagIds;

  const SearchFilters({
    this.isVegetarian = false,
    this.isHalal = false,
    this.isSpicy = false,
    this.topRated = false,
    this.minRating,
    this.categoryId,
    this.subCategoryId,
    this.masterCategoryId,
    this.cuisineTypeIds = const [],
    this.mealTypes = const [],
    this.tagIds = const [],
  });

  static const empty = SearchFilters();

  /// Whether any filter is active (used to show the "filtered" badge).
  bool get hasAny =>
      isVegetarian ||
      isHalal ||
      isSpicy ||
      topRated ||
      minRating != null ||
      categoryId != null ||
      subCategoryId != null ||
      masterCategoryId != null ||
      cuisineTypeIds.isNotEmpty ||
      mealTypes.isNotEmpty ||
      tagIds.isNotEmpty;

  /// Number of active dietary flags (Vegetarian / Halal / Spicy).
  int get dietaryCount {
    var count = 0;
    if (isVegetarian) count++;
    if (isHalal) count++;
    if (isSpicy) count++;
    return count;
  }

  /// Number of active filters, for a count badge.
  int get activeCount {
    var count = 0;
    if (isVegetarian) count++;
    if (isHalal) count++;
    if (isSpicy) count++;
    if (topRated) count++;
    if (minRating != null) count++;
    if (categoryId != null) count++;
    if (subCategoryId != null) count++;
    if (masterCategoryId != null) count++;
    if (cuisineTypeIds.isNotEmpty) count++;
    if (mealTypes.isNotEmpty) count++;
    if (tagIds.isNotEmpty) count++;
    return count;
  }

  /// Serializes only the active filters. The backend reads booleans as the
  /// string `'true'` and arrays as comma-separated values.
  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{};
    if (isVegetarian) params['isVegetarian'] = 'true';
    if (isHalal) params['isHalal'] = 'true';
    if (isSpicy) params['isSpicy'] = 'true';
    if (topRated) params['topRated'] = 'true';
    // `minRating` is intentionally NOT sent: the backend has no such param.
    // It is applied client-side (see FoodSearchPage._filteredShopResults).
    if (categoryId != null) params['categoryId'] = categoryId;
    if (subCategoryId != null) params['subCategoryId'] = subCategoryId;
    if (masterCategoryId != null) params['masterCategoryId'] = masterCategoryId;
    if (cuisineTypeIds.isNotEmpty) {
      params['cuisineTypeIds'] = cuisineTypeIds.join(',');
    }
    if (mealTypes.isNotEmpty) params['mealTypes'] = mealTypes.join(',');
    if (tagIds.isNotEmpty) params['tagIds'] = tagIds.join(',');
    return params;
  }

  SearchFilters copyWith({
    bool? isVegetarian,
    bool? isHalal,
    bool? isSpicy,
    bool? topRated,
    double? minRating,
    bool clearMinRating = false,
    int? categoryId,
    bool clearCategoryId = false,
    int? subCategoryId,
    int? masterCategoryId,
    bool clearMasterCategoryId = false,
    List<int>? cuisineTypeIds,
    List<String>? mealTypes,
    List<int>? tagIds,
  }) {
    return SearchFilters(
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isHalal: isHalal ?? this.isHalal,
      isSpicy: isSpicy ?? this.isSpicy,
      topRated: topRated ?? this.topRated,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      subCategoryId: subCategoryId ?? this.subCategoryId,
      masterCategoryId: clearMasterCategoryId
          ? null
          : (masterCategoryId ?? this.masterCategoryId),
      cuisineTypeIds: cuisineTypeIds ?? this.cuisineTypeIds,
      mealTypes: mealTypes ?? this.mealTypes,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}
