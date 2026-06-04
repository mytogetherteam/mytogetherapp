/// Mirrors the recipient-facing broadcast returned by `GET /api/announcements`.
/// Backend: myshop_demo_api/src/modules/broadcast/user/broadcast-user.service.ts
class AnnouncementModel {
  final int id;
  final String title;
  final String message;
  final String? audience;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    this.audience,
    this.data,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    final readRaw = json['readAt'];
    return AnnouncementModel(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      audience: json['audience']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
      createdAt: createdRaw != null
          ? DateTime.parse(createdRaw.toString())
          : DateTime.now(),
      isRead: json['isRead'] == true || json['read'] == true,
      readAt: readRaw != null ? DateTime.parse(readRaw.toString()) : null,
    );
  }

  AnnouncementModel copyWith({bool? isRead, DateTime? readAt}) {
    return AnnouncementModel(
      id: id,
      title: title,
      message: message,
      audience: audience,
      data: data,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }
}
