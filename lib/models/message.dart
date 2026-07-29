enum MessageStatus { pending, sent, delivered, read, failed }

enum MessageType { text, image, system, voice, video, document }

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.isOutgoing,
    required this.status,
    required this.createdAt,
    this.type = MessageType.text,
    this.sentAt,
    this.deliveredAt,
    this.replyToId,
    this.isDeleted = false,
    this.expiresAt,
    this.forwardedFrom,
  });

  final String id;
  final String conversationId;
  final String body;
  final bool isOutgoing;
  final MessageStatus status;
  final MessageType type;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final String? replyToId;
  final bool isDeleted;
  final DateTime? expiresAt;
  final String? forwardedFrom;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Message copyWith({
    String? id,
    String? conversationId,
    String? body,
    bool? isOutgoing,
    MessageStatus? status,
    MessageType? type,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    String? replyToId,
    bool? isDeleted,
    DateTime? expiresAt,
    String? forwardedFrom,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      body: body ?? this.body,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      replyToId: replyToId ?? this.replyToId,
      isDeleted: isDeleted ?? this.isDeleted,
      expiresAt: expiresAt ?? this.expiresAt,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'body': body,
      'is_outgoing': isOutgoing ? 1 : 0,
      'status': status.index,
      'type': type.index,
      'created_at': createdAt.millisecondsSinceEpoch,
      'sent_at': sentAt?.millisecondsSinceEpoch,
      'delivered_at': deliveredAt?.millisecondsSinceEpoch,
      'reply_to_id': replyToId,
      'is_deleted': isDeleted ? 1 : 0,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'forwarded_from': forwardedFrom,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      body: map['body'] as String,
      isOutgoing: (map['is_outgoing'] as int) == 1,
      status: MessageStatus.values[map['status'] as int],
      type: MessageType.values[map['type'] as int? ?? 0],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      sentAt: map['sent_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['sent_at'] as int)
          : null,
      deliveredAt: map['delivered_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['delivered_at'] as int)
          : null,
      replyToId: map['reply_to_id'] as String?,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
          : null,
      forwardedFrom: map['forwarded_from'] as String?,
    );
  }
}
