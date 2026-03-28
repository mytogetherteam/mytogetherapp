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

  factory Review.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    final dateStr = json['date']?.toString() ?? '';
    if (dateStr.contains('day')) {
      final days = int.tryParse(dateStr.split(' ')[0]) ?? 1;
      parsedDate = DateTime.now().subtract(Duration(days: days));
    } else if (dateStr.contains('week')) {
      final weeks = int.tryParse(dateStr.split(' ')[0]) ?? 1;
      parsedDate = DateTime.now().subtract(Duration(days: weeks * 7));
    } else if (dateStr.contains('month')) {
      final months = int.tryParse(dateStr.split(' ')[0]) ?? 1;
      parsedDate = DateTime.now().subtract(Duration(days: months * 30));
    } else {
      parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    }

    return Review(
      id: json['id']?.toString() ?? '',
      userAvatar: json['userAvatar'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Anonymous',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      text: json['comment'] as String? ?? json['text'] as String? ?? '',
      photoUrl: json['image'] as String? ?? json['photoUrl'] as String? ?? '',
      date: parsedDate,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
