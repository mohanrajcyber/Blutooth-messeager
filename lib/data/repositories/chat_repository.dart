import '../../models/conversation.dart';
import '../../models/message.dart';
import '../database/app_database.dart';

class ConversationRepository {
  ConversationRepository(this._db);

  final AppDatabase _db;

  Future<List<Conversation>> getAll() => _db.getConversations();

  Future<Conversation?> getByPeerId(String peerId) =>
      _db.getConversationByPeerId(peerId);

  Future<Conversation> getOrCreate(String peerId, String peerName) async {
    final existing = await _db.getConversationByPeerId(peerId);
    if (existing != null) return existing;

    final conversation = Conversation(
      id: peerId,
      peerId: peerId,
      peerName: peerName,
      updatedAt: DateTime.now(),
    );
    await _db.upsertConversation(conversation);
    return conversation;
  }

  Future<void> updatePreview(
    String conversationId, {
    required String lastMessage,
    bool incrementUnread = false,
  }) async {
    final conversations = await _db.getConversations();
    final match = conversations.where((c) => c.id == conversationId).firstOrNull;
    if (match == null) return;

    await _db.upsertConversation(
      match.copyWith(
        lastMessage: lastMessage,
        unreadCount: incrementUnread ? match.unreadCount + 1 : match.unreadCount,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> markRead(String conversationId) =>
      _db.markConversationRead(conversationId);
}

class MessageRepository {
  MessageRepository(this._db);

  final AppDatabase _db;

  Future<List<Message>> getForConversation(String conversationId) =>
      _db.getMessages(conversationId);

  Future<void> save(Message message) => _db.insertMessage(message);

  Future<void> updateStatus(
    String messageId,
    MessageStatus status, {
    DateTime? sentAt,
    DateTime? deliveredAt,
  }) =>
      _db.updateMessageStatus(
        messageId,
        status,
        sentAt: sentAt,
        deliveredAt: deliveredAt,
      );

  Future<void> enqueueOutbox(String messageId, String peerId) =>
      _db.enqueueOutbox(messageId, peerId);

  Future<void> dequeueOutbox(String messageId) =>
      _db.removeFromOutbox(messageId);
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
