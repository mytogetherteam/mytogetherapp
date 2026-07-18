/// Models mirroring the backend `user/chat` contract.
library;

import 'package:mytogetherapp/core/network/media_url.dart';

enum ChatSenderType { user, shop, system }

enum ChatMessageKind { text, image, voice, mixed, system }

enum ChatAttachmentKind { image, voice, video, file }

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
    case 'VOICE':
      return ChatMessageKind.voice;
    case 'MIXED':
      return ChatMessageKind.mixed;
    case 'SYSTEM':
      return ChatMessageKind.system;
    case 'TEXT':
    default:
      return ChatMessageKind.text;
  }
}

ChatAttachmentKind _parseAttachmentKind(dynamic value) {
  switch ((value as String?)?.toUpperCase()) {
    case 'VOICE':
      return ChatAttachmentKind.voice;
    case 'VIDEO':
      return ChatAttachmentKind.video;
    case 'FILE':
      return ChatAttachmentKind.file;
    case 'IMAGE':
    default:
      return ChatAttachmentKind.image;
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

class ChatAttachment {
  final int id;
  final ChatAttachmentKind kind;
  final String url;
  final String? thumbnailUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final int? durationSeconds;
  final int sortOrder;

  const ChatAttachment({
    required this.id,
    required this.kind,
    required this.url,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.durationSeconds,
    this.sortOrder = 0,
  });

  bool get isVoice => kind == ChatAttachmentKind.voice;
  bool get isImage => kind == ChatAttachmentKind.image;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: _parseAttachmentKind(json['type']),
      url: resolveMediaUrl(json['url']?.toString()),
      thumbnailUrl: resolveMediaUrl(json['thumbnailUrl']?.toString()),
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      durationSeconds: (json['duration'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final int? conversationId;
  final ChatSenderType senderType;
  final ChatMessageKind kind;
  final String? content;
  final String? attachmentUrl;
  final List<ChatAttachment> attachments;
  final int? durationSeconds;
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
    this.attachments = const [],
    this.durationSeconds,
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

  bool get isVoice =>
      kind == ChatMessageKind.voice ||
      (kind == ChatMessageKind.mixed && voiceAttachment != null);

  ChatAttachment? get voiceAttachment {
    for (final attachment in attachments) {
      if (attachment.isVoice) return attachment;
    }
    return null;
  }

  String? get voiceUrl {
    final fromAttachment = voiceAttachment?.url;
    if (fromAttachment != null && fromAttachment.isNotEmpty) {
      return fromAttachment;
    }
    if (isVoice && attachmentUrl != null && attachmentUrl!.isNotEmpty) {
      return attachmentUrl;
    }
    return null;
  }

  int get voiceDurationSeconds =>
      voiceAttachment?.durationSeconds ?? durationSeconds ?? 0;

  String get text => content ?? '';
  DateTime get timestamp => createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = (json['senderUser'] ??
            json['senderAdmin'] ??
            json['senderShop']) as Map?;
    final attachments = (json['attachments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ChatAttachment.fromJson(e.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    ChatAttachment? firstVoice;
    ChatAttachment? firstImage;
    for (final attachment in attachments) {
      firstVoice ??= attachment.isVoice ? attachment : null;
      firstImage ??= attachment.isImage ? attachment : null;
    }

    final legacyUrl = resolveMediaUrl(json['attachmentUrl']?.toString());
    final resolvedUrl = firstVoice?.url.isNotEmpty == true
        ? firstVoice!.url
        : (firstImage?.url.isNotEmpty == true
            ? firstImage!.url
            : (legacyUrl.isNotEmpty ? legacyUrl : null));

    return ChatMessage(
      id: json['id'].toString(),
      conversationId: (json['conversationId'] as num?)?.toInt(),
      senderType: _parseSenderType(json['senderType']),
      kind: _parseMessageKind(json['type']),
      content: json['content'] as String?,
      attachmentUrl: resolvedUrl,
      attachments: attachments,
      durationSeconds: firstVoice?.durationSeconds ??
          (json['duration'] as num?)?.toInt(),
      isRead: json['isRead'] == true,
      isDeleted: json['isDeleted'] == true,
      editedAt: _parseDate(json['editedAt']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      senderName: sender?['name'] as String?,
      senderAvatarUrl: resolveMediaUrl(
        (sender?['profileUrl'] ?? sender?['logoUrl'])?.toString(),
      ),
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
      attachments: attachments,
      durationSeconds: durationSeconds,
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
    if (kind == ChatMessageKind.voice) return '🎤 Voice message';
    if (kind == ChatMessageKind.mixed) {
      final attachments = message['attachments'] as List? ?? const [];
      final hasVoice = attachments.any(
        (a) =>
            a is Map &&
            (a['type'] as String?)?.toUpperCase() == 'VOICE',
      );
      if (hasVoice) return '🎤 Voice message';
      return '📷 Photo';
    }
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
      avatarUrl: resolveMediaUrl(
        (shop?['logoUrl'] ?? shop?['profileUrl'])?.toString(),
      ),
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
