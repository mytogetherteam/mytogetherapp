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
      categoryId != null ||
      subCategoryId != null ||
      masterCategoryId != null ||
      cuisineTypeIds.isNotEmpty ||
      mealTypes.isNotEmpty ||
      tagIds.isNotEmpty;

  /// Number of active filters, for a count badge.
  int get activeCount {
    var count = 0;
    if (isVegetarian) count++;
    if (isHalal) count++;
    if (isSpicy) count++;
    if (topRated) count++;
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
    int? categoryId,
    bool clearCategoryId = false,
    int? masterCategoryId,
    bool clearMasterCategoryId = false,
  }) {
    return SearchFilters(
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isHalal: isHalal ?? this.isHalal,
      isSpicy: isSpicy ?? this.isSpicy,
      topRated: topRated ?? this.topRated,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      subCategoryId: subCategoryId,
      masterCategoryId: clearMasterCategoryId
          ? null
          : (masterCategoryId ?? this.masterCategoryId),
      cuisineTypeIds: cuisineTypeIds,
      mealTypes: mealTypes,
      tagIds: tagIds,
    );
  }
}
