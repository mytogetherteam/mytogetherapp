/// Models mirroring the backend `user/chat` contract.
library;

enum ChatSenderType { user, shop, system }

enum ChatMessageKind { text, image, system }

ChatSenderType _parseSenderType(dynamic value) {
  switch ((value as String?)?.toUpperCase()) {
    case 'SHOP':
      return ChatSenderType.shop;
    case 'SYSTEM':
      return ChatSenderType.system;
    case 'USER':
    default:
      return ChatSenderType.user;
  }
}

ChatMessageKind _parseMessageKind(dynamic value) {
  switch ((value as String?)?.toUpperCase()) {
    case 'IMAGE':
      return ChatMessageKind.image;
    case 'SYSTEM':
      return ChatMessageKind.system;
    case 'TEXT':
    default:
      return ChatMessageKind.text;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString())?.toLocal();
}

String? _shopDisplayName(Map<String, dynamic>? shop) {
  if (shop == null) return null;
  for (final key in ['nameEn', 'name', 'nameTh', 'nameMm']) {
    final v = (shop[key] as String?)?.trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

class ChatMessage {
  final String id;
  final int? conversationId;
  final ChatSenderType senderType;
  final ChatMessageKind kind;
  final String? content;
  final String? attachmentUrl;
  final bool isRead;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatarUrl;

  const ChatMessage({
    required this.id,
    this.conversationId,
    required this.senderType,
    this.kind = ChatMessageKind.text,
    this.content,
    this.attachmentUrl,
    this.isRead = false,
    this.isDeleted = false,
    this.editedAt,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  /// True when the message was sent by the current customer app user.
  bool get isMe => senderType == ChatSenderType.user;

  bool get isEdited => editedAt != null && !isDeleted;

  String get text => content ?? '';
  DateTime get timestamp => createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = (json['senderUser'] ??
            json['senderAdmin'] ??
            json['senderShop']) as Map?;
    return ChatMessage(
      id: json['id'].toString(),
      conversationId: (json['conversationId'] as num?)?.toInt(),
      senderType: _parseSenderType(json['senderType']),
      kind: _parseMessageKind(json['type']),
      content: json['content'] as String?,
      attachmentUrl: json['attachmentUrl'] as String?,
      isRead: json['isRead'] == true,
      isDeleted: json['isDeleted'] == true,
      editedAt: _parseDate(json['editedAt']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      senderName: sender?['name'] as String?,
      senderAvatarUrl: (sender?['profileUrl'] ?? sender?['logoUrl']) as String?,
    );
  }

  ChatMessage copyWith({
    String? content,
    bool? isRead,
    bool? isDeleted,
    DateTime? editedAt,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderType: senderType,
      kind: kind,
      content: content ?? this.content,
      attachmentUrl: attachmentUrl,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
    );
  }
}

class ChatConversation {
  final int id;
  final int orderId;
  final String name;
  final String? avatarUrl;
  final String? orderNo;
  final String? orderStatus;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;

  const ChatConversation({
    required this.id,
    required this.orderId,
    required this.name,
    this.avatarUrl,
    this.orderNo,
    this.orderStatus,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
  });

  static String previewFor(Map<String, dynamic>? message) {
    if (message == null) return '';
    if (message['isDeleted'] == true) return 'Message deleted';
    final kind = _parseMessageKind(message['type']);
    if (kind == ChatMessageKind.image) return '📷 Photo';
    return (message['content'] as String?)?.trim() ?? '';
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    final shop = json['shop'] as Map<String, dynamic>?;
    final messages = json['messages'] as List?;
    final latest = (messages != null && messages.isNotEmpty)
        ? messages.first as Map<String, dynamic>
        : null;

    final shopName = _shopDisplayName(shop) ??
        (order?['shopName'] as String?)?.trim();

    return ChatConversation(
      id: (json['id'] as num).toInt(),
      orderId: ((order?['id'] ?? json['orderId']) as num).toInt(),
      name: (shopName != null && shopName.isNotEmpty) ? shopName : 'Shop',
      avatarUrl: (shop?['logoUrl'] ?? shop?['profileUrl']) as String?,
      orderNo: order?['lastOrderNo'] as String?,
      orderStatus: order?['status'] as String?,
      lastMessage: previewFor(latest),
      timestamp: _parseDate(json['lastMessageAt']) ??
          _parseDate(latest?['createdAt']) ??
          DateTime.now(),
      unreadCount: (json['userUnreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatPaged<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const ChatPaged({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory ChatPaged.fromResponse(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = (body['data'] as List?) ?? const [];
    final meta = (body['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ChatPaged<T>(
      items: data
          .map((e) => fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
    );
  }
}
