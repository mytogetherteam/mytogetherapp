class ShopReviewDto {
  final int id;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final String userName;

  /// Reviewer avatar URL (nested under `user.profileUrl`), when available.
  final String? userProfileUrl;

  /// Shop owner / admin reply to this review. Set by the backend
  /// (`POST /api/shop/reviews/:id/reply`); customers can read but not reply back.
  final String? shopReply;
  final DateTime? shopRepliedAt;

  /// Display name of who replied (admin/shop owner), when available.
  final String? shopReplyAuthorName;

  /// Avatar shown next to the reply. Prefers the replying admin's
  /// `repliedByAdmin.profileUrl`, falling back to the shop's `shop.logoUrl`.
  final String? shopReplyAvatarUrl;

  ShopReviewDto({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.userName,
    this.userProfileUrl,
    this.shopReply,
    this.shopRepliedAt,
    this.shopReplyAuthorName,
    this.shopReplyAvatarUrl,
  });

  /// Whether a non-empty shop reply exists to render.
  bool get hasShopReply => shopReply != null && shopReply!.trim().isNotEmpty;

  factory ShopReviewDto.fromJson(Map<String, dynamic> json) {
    // Public endpoint returns a flat `userName`; the authed user endpoint
    // (GET /api/user/shop/:id/reviews) nests it under `user.name`/`user.username`.
    final user = json['user'];
    final nestedName = user is Map
        ? (user['name'] as String? ?? user['username'] as String?)
        : null;
    final profileUrl = user is Map ? user['profileUrl'] as String? : null;
    final createdAtRaw = json['createdAt'];

    final repliedBy = json['repliedByAdmin'];
    final replyAuthorName = repliedBy is Map
        ? (repliedBy['name'] as String? ?? repliedBy['username'] as String?)
        : null;
    final adminAvatar = repliedBy is Map
        ? repliedBy['profileUrl'] as String?
        : null;
    final shop = json['shop'];
    final shopLogo = shop is Map ? shop['logoUrl'] as String? : null;
    final repliedAtRaw = json['shopRepliedAt'];

    return ShopReviewDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num? ?? 0.0).toDouble(),
      comment: json['comment'] as String?,
      createdAt: createdAtRaw is String
          ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
          : DateTime.now(),
      userName: json['userName'] as String? ?? nestedName ?? 'Customer',
      userProfileUrl: json['userProfileUrl'] as String? ?? profileUrl,
      shopReply: json['shopReply'] as String?,
      shopRepliedAt: repliedAtRaw is String
          ? DateTime.tryParse(repliedAtRaw)
          : null,
      shopReplyAuthorName: replyAuthorName,
      shopReplyAvatarUrl: adminAvatar ?? shopLogo,
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
