import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/chat_repository.dart';
import '../../models/message.dart';
import '../bluetooth/bluetooth_service.dart';
import '../local/code_pairing_service.dart';
import '../media/image_message_service.dart';

/// Coordinates local persistence, optimistic UI, and transport (BT or code).
class MessageService {
  MessageService({
    required BluetoothService bluetooth,
    required CodePairingService codePairing,
    required MessageRepository messages,
    required ConversationRepository conversations,
    ImageMessageService? images,
  })  : _bluetooth = bluetooth,
        _codePairing = codePairing,
        _messages = messages,
        _conversations = conversations,
        _images = images ?? ImageMessageService() {
    _incomingSub = _bluetooth.incomingStream.listen(_onBluetoothIncoming);
    _codeSub = _codePairing.incomingStream.listen(_onCodeIncoming);
  }

  final BluetoothService _bluetooth;
  final CodePairingService _codePairing;
  final MessageRepository _messages;
  final ConversationRepository _conversations;
  final ImageMessageService _images;
  final _uuid = const Uuid();

  final _messageEvents = StreamController<Message>.broadcast();
  StreamSubscription<IncomingPacket>? _incomingSub;
  StreamSubscription<Map<String, dynamic>>? _codeSub;

  Stream<Message> get messageEvents => _messageEvents.stream;

  bool _isLocalPeer(String peerId) =>
      peerId.startsWith(AppConstants.localPeerPrefix);

  Future<bool> _transportSend(String peerId, Map<String, dynamic> payload) {
    if (_isLocalPeer(peerId)) {
      return _codePairing.send(payload);
    }
    return _bluetooth.send(peerId, payload);
  }

  Future<Message> sendText({
    required String peerId,
    required String peerName,
    required String text,
  }) async {
    return _send(
      peerId: peerId,
      peerName: peerName,
      body: text,
      type: MessageType.text,
      payload: {
        'type': 'text',
        'body': text,
      },
    );
  }

  Future<Message> sendImage({
    required String peerId,
    required String peerName,
    required String imagePath,
  }) async {
    if (!_isLocalPeer(peerId)) {
      throw UnsupportedError('Images work over code/WiFi connection only');
    }

    final base64 = await _images.readAsBase64(imagePath);
    if (base64 == null) {
      throw StateError('Could not read image');
    }

    return _send(
      peerId: peerId,
      peerName: peerName,
      body: imagePath,
      type: MessageType.image,
      payload: {
        'type': 'image',
        'body': base64,
        'mime': 'image/jpeg',
      },
    );
  }

  Future<Message> _send({
    required String peerId,
    required String peerName,
    required String body,
    required MessageType type,
    required Map<String, dynamic> payload,
  }) async {
    final conversation = await _conversations.getOrCreate(peerId, peerName);
    final now = DateTime.now();
    final messageId = _uuid.v4();

    final message = Message(
      id: messageId,
      conversationId: conversation.id,
      body: body,
      isOutgoing: true,
      status: MessageStatus.pending,
      type: type,
      createdAt: now,
    );

    await _messages.save(message);
    await _conversations.updatePreview(
      conversation.id,
      lastMessage: type == MessageType.image ? '📷 Photo' : body,
    );
    _messageEvents.add(message);

    payload['id'] = messageId;
    payload['timestamp'] = now.millisecondsSinceEpoch;

    final sent = await _transportSend(peerId, payload);

    if (sent) {
      final updated = message.copyWith(
        status: MessageStatus.delivered,
        sentAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );
      await _messages.updateStatus(
        message.id,
        MessageStatus.delivered,
        sentAt: updated.sentAt,
        deliveredAt: updated.deliveredAt,
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

  Future<void> retryMessage(Message message, String peerId, String peerName) async {
    if (message.status != MessageStatus.failed) return;

    await _messages.updateStatus(message.id, MessageStatus.pending);
    _messageEvents.add(message.copyWith(status: MessageStatus.pending));

    final payload = <String, dynamic>{
      'id': message.id,
      'timestamp': message.createdAt.millisecondsSinceEpoch,
    };

    if (message.type == MessageType.image) {
      final base64 = await _images.readAsBase64(message.body);
      if (base64 == null) return;
      payload['type'] = 'image';
      payload['body'] = base64;
      payload['mime'] = 'image/jpeg';
    } else {
      payload['type'] = 'text';
      payload['body'] = message.body;
    }

    final sent = await _transportSend(peerId, payload);
    if (sent) {
      await _messages.updateStatus(
        message.id,
        MessageStatus.delivered,
        sentAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );
      _messageEvents.add(
        message.copyWith(
          status: MessageStatus.delivered,
          sentAt: DateTime.now(),
          deliveredAt: DateTime.now(),
        ),
      );
      await _messages.dequeueOutbox(message.id);
    }
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
    final type = payload['type'] as String?;
    if (type == 'ping') {
      await _codePairing.send({'type': 'pong'});
      return;
    }
    if (type == 'pong' || type == 'hello' || type == 'ack') return;

    if (type == 'text' || type == 'image') {
      await _handleIncoming(
        peerId: _codePairing.localPeerId,
        payload: payload,
        ack: (_) async {},
      );
    }
  }

  Future<void> _handleIncoming({
    required String peerId,
    required Map<String, dynamic> payload,
    required Future<void> Function(String id) ack,
  }) async {
    final type = payload['type'] as String?;
    if (type != 'text' && type != 'image') return;

    final messageId = payload['id'] as String? ?? _uuid.v4();
    final timestamp = payload['timestamp'] as int?;
    final isImage = type == 'image';

    var body = payload['body'] as String? ?? '';
    if (isImage) {
      final saved = await _images.saveIncomingBase64(body);
      if (saved == null) return;
      body = saved;
    }

    final peerName = _codePairing.connectedPeerName ??
        (peerId.length > 8 ? peerId.substring(0, 8) : peerId);
    final conversation = await _conversations.getOrCreate(peerId, peerName);

    final message = Message(
      id: messageId,
      conversationId: conversation.id,
      body: body,
      isOutgoing: false,
      status: MessageStatus.delivered,
      type: isImage ? MessageType.image : MessageType.text,
      createdAt: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.now(),
      deliveredAt: DateTime.now(),
    );

    await _messages.save(message);
    await _conversations.updatePreview(
      conversation.id,
      lastMessage: isImage ? '📷 Photo' : body,
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
