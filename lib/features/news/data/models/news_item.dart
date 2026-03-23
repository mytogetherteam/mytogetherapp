class NewsItem {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String content;
  final List<String> imageUrls;
  int likesCount;
  final int commentsCount;
  final String timeAgo;
  bool isLiked;

  final String? location;
  final String? rewardAmount;
  final String? phoneNumber;

  NewsItem({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.imageUrls,
    required this.likesCount,
    required this.commentsCount,
    required this.timeAgo,
    this.isLiked = false,
    this.location,
    this.rewardAmount,
    this.phoneNumber,
  });
}
