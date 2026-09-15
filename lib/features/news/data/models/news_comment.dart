class NewsComment {
  final int? id;
  final String authorName;
  final String authorAvatar;
  final String content;
  final String timeAgo;
  final bool isMine;

  NewsComment({
    this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timeAgo,
    this.isMine = false,
  });

  NewsComment copyWith({String? content}) {
    return NewsComment(
      id: id,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content ?? this.content,
      timeAgo: timeAgo,
      isMine: isMine,
    );
  }
}
