class Review {
  final String id;
  final String userAvatar;
  final String userName;
  final int rating;
  final String text;
  final String photoUrl;
  final DateTime date;
  final List<String> tags;

  Review({
    required this.id,
    required this.userAvatar,
    required this.userName,
    required this.rating,
    required this.text,
    required this.photoUrl,
    required this.date,
    required this.tags,
  });
}
