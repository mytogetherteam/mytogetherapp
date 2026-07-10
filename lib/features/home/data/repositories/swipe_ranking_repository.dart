import '../../../../core/network/api_client.dart';
import '../models/shop_feed_item_dto.dart';

class SwipeRankingRepository {
  static final SwipeRankingRepository instance = SwipeRankingRepository._();
  SwipeRankingRepository._();

  Future<List<ShopFeedItemDto>> getSwipeCandidates({int limit = 20}) async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/menu-items/swipe-candidates',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((json) => ShopFeedItemDto.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching swipe candidates: $e');
    }
    return [];
  }

  Future<List<ShopFeedItemDto>> getLeaderboard({int limit = 20}) async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/menu-items/leaderboard',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((json) => ShopFeedItemDto.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
    }
    return [];
  }

  Future<void> submitSwipe(int menuItemId, bool isLike) async {
    try {
      await ApiClient().dio.post(
        '${ApiClient.apiPrefix}/user/menu-items/$menuItemId/swipe',
        data: {'isLike': isLike},
      );
    } catch (e) {
      print('Error submitting swipe: $e');
    }
  }

  Future<List<ShopFeedItemDto>> getTodayLikedItems() async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiClient.apiPrefix}/user/menu-items/swipe-history/today',
      );
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => ShopFeedItemDto.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching today liked items: $e');
      return [];
    }
  }
}
