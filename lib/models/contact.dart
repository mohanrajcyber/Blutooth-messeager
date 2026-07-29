class SavedContact {
  const SavedContact({
    required this.id,
    required this.name,
    required this.code,
    this.peerId,
    this.avatarPath,
    this.lastSeen,
  });

  final String id;
  final String name;
  final String code;
  final String? peerId;
  final String? avatarPath;
  final DateTime? lastSeen;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'peer_id': peerId,
        'avatar_path': avatarPath,
        'last_seen': lastSeen?.millisecondsSinceEpoch,
      };

  factory SavedContact.fromMap(Map<String, dynamic> map) => SavedContact(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String,
        peerId: map['peer_id'] as String?,
        avatarPath: map['avatar_path'] as String?,
        lastSeen: map['last_seen'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int)
            : null,
      );
}

class StatusStory {
  const StatusStory({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    this.type = 'text',
    this.mediaPath,
  });

  final String id;
  final String body;
  final String type;
  final String? mediaPath;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'id': id,
        'body': body,
        'type': type,
        'media_path': mediaPath,
        'created_at': createdAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
      };

  factory StatusStory.fromMap(Map<String, dynamic> map) => StatusStory(
        id: map['id'] as String,
        body: map['body'] as String,
        type: map['type'] as String? ?? 'text',
        mediaPath: map['media_path'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      );
}
