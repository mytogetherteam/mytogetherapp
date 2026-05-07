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
    return ShopReviewDto(
      id: json['id'] as int? ?? 0,
      rating: (json['rating'] as num? ?? 0.0).toDouble(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userName: json['userName'] as String? ?? 'Customer',
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
