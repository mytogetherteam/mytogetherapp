class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String type;
  final int? referenceId;
  final String? imageUrl;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool read;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    this.imageUrl,
    required this.sentAt,
    this.readAt,
    required this.read,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Determine title and body based on available localized fields or defaults
    // The API seems to have title, titleMm, titleTh, titleEn etc.
    // For now we'll use 'title' and 'body' but fallback to 'titleEn' if available.
    String resolvedTitle = json['titleEn'] ?? json['title'] ?? '';
    String resolvedBody = json['bodyEn'] ?? json['body'] ?? '';

    return NotificationModel(
      id: json['id'],
      title: resolvedTitle,
      body: resolvedBody,
      type: json['type'] ?? 'GENERAL',
      referenceId: json['referenceId'],
      imageUrl: json['imageUrl'],
      sentAt: DateTime.parse(json['sentAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'referenceId': referenceId,
      'imageUrl': imageUrl,
      'sentAt': sentAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'read': read,
    };
  }
}
