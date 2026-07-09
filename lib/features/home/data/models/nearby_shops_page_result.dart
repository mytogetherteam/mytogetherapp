import '../../../../core/utils/api_response_utils.dart';
import '../restaurant_data.dart';

/// Paginated nearby shops with API-backed continuation metadata.
class NearbyShopsPageResult {
  final List<Restaurant> restaurants;
  final int page;
  final int lastPage;
  final int total;
  final int pageSize;

  const NearbyShopsPageResult({
    required this.restaurants,
    required this.page,
    required this.lastPage,
    required this.total,
    this.pageSize = 20,
  });

  bool get hasMore => ApiResponseUtils.hasMorePages(
        page: page,
        lastPage: lastPage,
        itemCount: restaurants.length,
        pageSize: pageSize,
        totalCount: total,
      );
}
