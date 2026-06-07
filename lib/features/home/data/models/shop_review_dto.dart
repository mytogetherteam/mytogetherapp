class ShopReviewDto {
  final int id;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final String userName;

  ShopReviewDto({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.userName,
  });

  factory ShopReviewDto.fromJson(Map<String, dynamic> json) {
    // Public endpoint returns a flat `userName`; the authed user endpoint
    // (GET /api/user/shop/:id/reviews) nests it under `user.name`/`user.username`.
    final user = json['user'];
    final nestedName = user is Map
        ? (user['name'] as String? ?? user['username'] as String?)
        : null;
    final createdAtRaw = json['createdAt'];
    return ShopReviewDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num? ?? 0.0).toDouble(),
      comment: json['comment'] as String?,
      createdAt: createdAtRaw is String
          ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
          : DateTime.now(),
      userName: json['userName'] as String? ?? nestedName ?? 'Customer',
    );
  }
}

class ShopReviewSummaryDto {
  final int totalCount;
  final double averageRating;
  final Map<int, int> ratingStats;

  ShopReviewSummaryDto({
    required this.totalCount,
    required this.averageRating,
    required this.ratingStats,
  });

  factory ShopReviewSummaryDto.fromJson(Map<String, dynamic> json) {
    // Handle { success: true, data: { ... } } wrapper
    final data = json['data'] as Map<String, dynamic>? ?? json;
    
    final stats = data['ratingDistribution'] as Map<String, dynamic>? ?? {};
    final mappedStats = <int, int>{};
    stats.forEach((key, value) {
      mappedStats[int.parse(key)] = value as int? ?? 0;
    });

    return ShopReviewSummaryDto(
      totalCount: data['totalRatings'] as int? ?? 0,
      averageRating: (data['averageRating'] as num? ?? 0.0).toDouble(),
      ratingStats: mappedStats,
    );
  }
}
