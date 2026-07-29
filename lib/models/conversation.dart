class Conversation {
  const Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.isConnected = false,
    this.isGroup = false,
    this.wallpaper,
    this.bubbleColor,
  });

  final String id;
  final String peerId;
  final String peerName;
  final String? lastMessage;
  final int unreadCount;
  final bool isConnected;
  final bool isGroup;
  final String? wallpaper;
  final String? bubbleColor;
  final DateTime updatedAt;

  Conversation copyWith({
    String? id,
    String? peerId,
    String? peerName,
    String? lastMessage,
    int? unreadCount,
    bool? isConnected,
    bool? isGroup,
    String? wallpaper,
    String? bubbleColor,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isConnected: isConnected ?? this.isConnected,
      isGroup: isGroup ?? this.isGroup,
      wallpaper: wallpaper ?? this.wallpaper,
      bubbleColor: bubbleColor ?? this.bubbleColor,
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
      'is_group': isGroup ? 1 : 0,
      'wallpaper': wallpaper,
      'bubble_color': bubbleColor,
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
      isGroup: (map['is_group'] as int? ?? 0) == 1,
      wallpaper: map['wallpaper'] as String?,
      bubbleColor: map['bubble_color'] as String?,
    );
  }
}
