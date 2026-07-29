class Conversation {
  const Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.isConnected = false,
  });

  final String id;
  final String peerId;
  final String peerName;
  final String? lastMessage;
  final int unreadCount;
  final bool isConnected;
  final DateTime updatedAt;

  Conversation copyWith({
    String? id,
    String? peerId,
    String? peerName,
    String? lastMessage,
    int? unreadCount,
    bool? isConnected,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isConnected: isConnected ?? this.isConnected,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peer_id': peerId,
      'peer_name': peerName,
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      peerId: map['peer_id'] as String,
      peerName: map['peer_name'] as String,
      lastMessage: map['last_message'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
