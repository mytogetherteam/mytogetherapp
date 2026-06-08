import '../../../../core/localization/locale_controller.dart';
import 'news_dto.dart';
import '../../../lost_and_found/data/models/item_post_dto.dart';

enum FeedSource { news, itemPost }

class NewsItem {
  final String id;
  final int? entityId;
  final FeedSource source;
  final String authorName;
  final String authorAvatar;
  final String content;
  final List<String> imageUrls;
  int likesCount;
  int commentsCount;
  final String timeAgo;
  bool isLiked;

  final String? location;
  final String? phoneNumber;
  final String? itemPostType;

  NewsItem({
    required this.id,
    this.entityId,
    required this.source,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.imageUrls,
    required this.likesCount,
    required this.commentsCount,
    required this.timeAgo,
    this.isLiked = false,
    this.location,
    this.phoneNumber,
    this.itemPostType,
  });

  bool get isApiBacked => entityId != null;

  factory NewsItem.fromNewsArticle(NewsArticleDto dto) {
    return NewsItem(
      id: dto.id.toString(),
      entityId: dto.id,
      source: FeedSource.news,
      authorName: dto.createdByAdmin?.displayName ??
          LocaleController.instance.tr('news.author_fallback'),
      authorAvatar: dto.createdByAdmin?.profileUrl ?? '',
      content: dto.feedContent,
      imageUrls: dto.imageUrls,
      likesCount: dto.likeCount,
      commentsCount: dto.commentCount,
      timeAgo: dto.timeAgo,
      isLiked: dto.likedByMe,
    );
  }

  factory NewsItem.fromItemPost(ItemPostDto dto) {
    return NewsItem(
      id: dto.id.toString(),
      entityId: dto.id,
      source: FeedSource.itemPost,
      authorName: dto.user?.displayName ?? 'User',
      authorAvatar: dto.user?.profileUrl ?? '',
      content: dto.description,
      imageUrls: dto.imageUrls,
      likesCount: dto.likeCount,
      commentsCount: dto.commentCount,
      timeAgo: dto.timeAgo,
      isLiked: dto.likedByMe,
      location: dto.locationLabel,
      phoneNumber: dto.phoneNumber,
      itemPostType: dto.type,
    );
  }
}
