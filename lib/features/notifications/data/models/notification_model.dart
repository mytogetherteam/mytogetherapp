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
    final mainType = json['mainType']?.toString();
    final subType = json['subType']?.toString();

    // Map NestJS notification enums to legacy UI type strings.
    final String type;
    if (mainType == 'ORDER') {
      type = 'ORDER_STATUS';
    } else if (mainType == 'ESCALATION') {
      type = 'SYSTEM';
    } else {
      type = json['type']?.toString() ?? subType ?? 'GENERAL';
    }

    final dynamic dataField = json['data'];
    final int? referenceId = _parseReferenceId(
      json['orderId'] ?? json['referenceId'] ??
          (dataField is Map
              ? (dataField['orderId'] ?? dataField['referenceId'])
              : null),
    );

    final sentAtRaw = json['createdAt'] ?? json['sentAt'];
    final readAtRaw = json['readAt'];

    return NotificationModel(
      id: json['id'] as int,
      title: json['title']?.toString() ?? json['titleEn']?.toString() ?? '',
      body: json['message']?.toString() ??
          json['body']?.toString() ??
          json['bodyEn']?.toString() ??
          '',
      type: type,
      referenceId: referenceId,
      imageUrl: json['imageUrl']?.toString(),
      sentAt: sentAtRaw != null
          ? DateTime.parse(sentAtRaw.toString())
          : DateTime.now(),
      readAt:
          readAtRaw != null ? DateTime.parse(readAtRaw.toString()) : null,
      read: json['isRead'] == true || json['read'] == true,
    );
  }

  static int? _parseReferenceId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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
