import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/chat_repository.dart';
import '../../models/message.dart';
import '../bluetooth/bluetooth_service.dart';
import '../local/code_pairing_service.dart';

/// Coordinates local persistence, optimistic UI, and transport (BT or code).
class MessageService {
  MessageService({
    required BluetoothService bluetooth,
    required CodePairingService codePairing,
    required MessageRepository messages,
    required ConversationRepository conversations,
  })  : _bluetooth = bluetooth,
        _codePairing = codePairing,
        _messages = messages,
        _conversations = conversations {
    _incomingSub = _bluetooth.incomingStream.listen(_onBluetoothIncoming);
    _codeSub = _codePairing.incomingStream.listen(_onCodeIncoming);
  }

  final BluetoothService _bluetooth;
  final CodePairingService _codePairing;
  final MessageRepository _messages;
  final ConversationRepository _conversations;
  final _uuid = const Uuid();

  final _messageEvents = StreamController<Message>.broadcast();
  StreamSubscription<IncomingPacket>? _incomingSub;
  StreamSubscription<Map<String, dynamic>>? _codeSub;

  Stream<Message> get messageEvents => _messageEvents.stream;

  bool _isLocalPeer(String peerId) =>
      peerId.startsWith(AppConstants.localPeerPrefix);

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

    await _messages.save(message);
    await _conversations.updatePreview(conversation.id, lastMessage: text);
    _messageEvents.add(message);

    final payload = {
      'type': 'text',
      'id': message.id,
      'body': text,
      'timestamp': now.millisecondsSinceEpoch,
    };

    final sent = _isLocalPeer(peerId)
        ? await _codePairing.send(payload)
        : await _bluetooth.send(peerId, payload);

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

  Future<void> _onBluetoothIncoming(IncomingPacket packet) async {
    await _handleIncoming(
      peerId: packet.peerId,
      payload: packet.payload,
      ack: (id) => _bluetooth.send(packet.peerId, {
        'type': 'ack',
        'message_id': id,
      }),
    );
  }

  Future<void> _onCodeIncoming(Map<String, dynamic> payload) async {
    if (payload['type'] != 'text') return;
    await _handleIncoming(
      peerId: _codePairing.localPeerId,
      payload: payload,
      ack: (_) async {},
    );
  }

  Future<void> _handleIncoming({
    required String peerId,
    required Map<String, dynamic> payload,
    required Future<void> Function(String id) ack,
  }) async {
    final type = payload['type'] as String?;
    if (type != 'text') return;

    final body = payload['body'] as String? ?? '';
    final messageId = payload['id'] as String? ?? _uuid.v4();
    final timestamp = payload['timestamp'] as int?;

    final peerName = _codePairing.connectedPeerName ??
        (peerId.length > 8 ? peerId.substring(0, 8) : peerId);
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
    await ack(messageId);
  }

  Future<void> dispose() async {
    await _incomingSub?.cancel();
    await _codeSub?.cancel();
    await _messageEvents.close();
  }
}
