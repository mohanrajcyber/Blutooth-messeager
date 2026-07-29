import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/chat_repository.dart';
import '../../models/message.dart';
import '../bluetooth/bluetooth_service.dart';

/// Coordinates local persistence, optimistic UI, and Bluetooth transport.
class MessageService {
  MessageService({
    required BluetoothService bluetooth,
    required MessageRepository messages,
    required ConversationRepository conversations,
  })  : _bluetooth = bluetooth,
        _messages = messages,
        _conversations = conversations {
    _incomingSub = _bluetooth.incomingStream.listen(_onIncoming);
  }

  final BluetoothService _bluetooth;
  final MessageRepository _messages;
  final ConversationRepository _conversations;
  final _uuid = const Uuid();

  final _messageEvents = StreamController<Message>.broadcast();
  StreamSubscription<IncomingPacket>? _incomingSub;

  Stream<Message> get messageEvents => _messageEvents.stream;

  Future<Message> sendText({
    required String peerId,
    required String peerName,
    required String text,
  }) async {
    final conversation = await _conversations.getOrCreate(peerId, peerName);
    final now = DateTime.now();

    final message = Message(
      id: _uuid.v4(),
      conversationId: conversation.id,
      body: text,
      isOutgoing: true,
      status: MessageStatus.pending,
      createdAt: now,
    );

    // Optimistic: persist and emit immediately
    await _messages.save(message);
    await _conversations.updatePreview(
      conversation.id,
      lastMessage: text,
    );
    _messageEvents.add(message);

    final payload = {
      'type': 'text',
      'id': message.id,
      'body': text,
      'timestamp': now.millisecondsSinceEpoch,
    };

    final sent = await _bluetooth.send(peerId, payload);
    if (sent) {
      final updated = message.copyWith(
        status: MessageStatus.sent,
        sentAt: DateTime.now(),
      );
      await _messages.updateStatus(
        message.id,
        MessageStatus.sent,
        sentAt: updated.sentAt,
      );
      _messageEvents.add(updated);
      await _messages.dequeueOutbox(message.id);
    } else {
      await _messages.enqueueOutbox(message.id, peerId);
      final failed = message.copyWith(status: MessageStatus.failed);
      await _messages.updateStatus(message.id, MessageStatus.failed);
      _messageEvents.add(failed);
    }

    return message;
  }

  Future<void> _onIncoming(IncomingPacket packet) async {
    final type = packet.payload['type'] as String?;
    if (type != 'text') return;

    final peerId = packet.peerId;
    final body = packet.payload['body'] as String? ?? '';
    final messageId =
        packet.payload['id'] as String? ?? _uuid.v4();
    final timestamp = packet.payload['timestamp'] as int?;

    final peerName = peerId.substring(0, 8);
    final conversation = await _conversations.getOrCreate(peerId, peerName);

    final message = Message(
      id: messageId,
      conversationId: conversation.id,
      body: body,
      isOutgoing: false,
      status: MessageStatus.delivered,
      createdAt: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.now(),
      deliveredAt: DateTime.now(),
    );

    await _messages.save(message);
    await _conversations.updatePreview(
      conversation.id,
      lastMessage: body,
      incrementUnread: true,
    );
    _messageEvents.add(message);

    // Ack delivery back to sender
    await _bluetooth.send(peerId, {
      'type': 'ack',
      'message_id': messageId,
    });
  }

  Future<void> dispose() async {
    await _incomingSub?.cancel();
    await _messageEvents.close();
  }
}

Future<MessageService> createMessageService() async {
  final db = AppDatabase.instance;
  await db.database;

  final bluetooth = BluetoothService();
  final messages = MessageRepository(db);
  final conversations = ConversationRepository(db);

  return MessageService(
    bluetooth: bluetooth,
    messages: messages,
    conversations: conversations,
  );
}
