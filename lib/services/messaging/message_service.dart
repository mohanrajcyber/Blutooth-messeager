import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/chat_repository.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/contact.dart';
import '../bluetooth/bluetooth_service.dart';
import '../local/code_pairing_service.dart';
import '../local/group_chat_service.dart';
import '../media/media_service.dart';
import '../notifications/notification_service.dart';
import '../security/encryption_service.dart';
import '../settings/settings_service.dart';

/// Full messaging hub — text, media, typing, read receipts, E2E, queue.
class MessageService {
  MessageService({
    required BluetoothService bluetooth,
    required CodePairingService codePairing,
    required GroupChatService groupChat,
    required MessageRepository messages,
    required ConversationRepository conversations,
    required SettingsService settings,
    required EncryptionService encryption,
    required AppDatabase db,
    MediaService? media,
  })  : _bluetooth = bluetooth,
        _codePairing = codePairing,
        _groupChat = groupChat,
        _messages = messages,
        _conversations = conversations,
        _settings = settings,
        _encryption = encryption,
        _db = db,
        _media = media ?? MediaService() {
    _incomingSub = _bluetooth.incomingStream.listen(_onBluetoothIncoming);
    _codeSub = _codePairing.incomingStream.listen(_onTransportEvent);
    _groupSub = _groupChat.incomingStream.listen(_onTransportEvent);
    _typingController = StreamController<String>.broadcast();
    _lastSeenController = StreamController<DateTime?>.broadcast();
    _outboxTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_processOutbox());
    });
    _expiryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_db.purgeExpiredMessages());
    });
  }

  final BluetoothService _bluetooth;
  final CodePairingService _codePairing;
  final GroupChatService _groupChat;
  final MessageRepository _messages;
  final ConversationRepository _conversations;
  final SettingsService _settings;
  final EncryptionService _encryption;
  final AppDatabase _db;
  final MediaService _media;
  final _uuid = const Uuid();

  final _messageEvents = StreamController<Message>.broadcast();
  late final StreamController<String> _typingController;
  late final StreamController<DateTime?> _lastSeenController;
  StreamSubscription<IncomingPacket>? _incomingSub;
  StreamSubscription<Map<String, dynamic>>? _codeSub;
  StreamSubscription<Map<String, dynamic>>? _groupSub;
  Timer? _outboxTimer;
  Timer? _expiryTimer;
  Timer? _typingTimer;

  Stream<Message> get messageEvents => _messageEvents.stream;
  Stream<String> get typingStream => _typingController.stream;
  Stream<DateTime?> get lastSeenStream => _lastSeenController.stream;
  MediaService get media => _media;

  bool _isLocalPeer(String peerId) =>
      peerId.startsWith(AppConstants.localPeerPrefix);

  Future<bool> _transportSend(String peerId, Map<String, dynamic> payload) async {
    if (await _db.isBlocked(peerId)) return false;

    final toSend = _encryption.isReady
        ? _encryption.encryptPayload(payload)
        : payload;

    if (peerId.contains('group:')) {
      return _groupChat.broadcast(toSend);
    }
    if (_isLocalPeer(peerId)) {
      return _codePairing.send(toSend);
    }
    return _bluetooth.send(peerId, toSend);
  }

  Map<String, dynamic>? _decrypt(Map<String, dynamic> payload) =>
      _encryption.decryptPayload(payload) ?? payload;

  void sendTyping(String peerId, {required bool active}) {
    unawaited(_transportSend(peerId, {'type': 'typing', 'active': active}));
    _typingTimer?.cancel();
    if (active) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        unawaited(_transportSend(peerId, {'type': 'typing', 'active': false}));
      });
    }
  }

  Future<void> sendReadReceipt(String peerId, List<String> messageIds) async {
    await _transportSend(peerId, {
      'type': 'read',
      'message_ids': messageIds,
    });
  }

  Future<void> sendDelete(String peerId, String messageId,
      {required bool forAll}) async {
    await _transportSend(peerId, {
      'type': 'delete',
      'message_id': messageId,
      'for_all': forAll,
    });
    await _db.deleteMessage(messageId);
  }

  Future<Message> sendText({
    required String peerId,
    required String peerName,
    required String text,
    String? replyToId,
    String? forwardedFrom,
  }) async {
    return _send(
      peerId: peerId,
      peerName: peerName,
      body: text,
      type: MessageType.text,
      payload: {'type': 'text', 'body': text},
      replyToId: replyToId,
      forwardedFrom: forwardedFrom,
    );
  }

  Future<Message> sendMedia({
    required String peerId,
    required String peerName,
    required String filePath,
    required MessageType type,
    required String mime,
  }) async {
    final base64 = await _media.readAsBase64(filePath);
    if (base64 == null) throw StateError('Could not read file');

    final preview = switch (type) {
      MessageType.image => '📷 Photo',
      MessageType.voice => '🎤 Voice',
      MessageType.video => '🎬 Video',
      MessageType.document => '📄 Document',
      _ => 'File',
    };

    return _send(
      peerId: peerId,
      peerName: peerName,
      body: filePath,
      type: type,
      preview: preview,
      payload: {
        'type': type.name,
        'body': base64,
        'mime': mime,
        'filename': filePath.split(RegExp(r'[/\\]')).last,
      },
    );
  }

  Future<Message> _send({
    required String peerId,
    required String peerName,
    required String body,
    required MessageType type,
    required Map<String, dynamic> payload,
    String preview = '',
    String? replyToId,
    String? forwardedFrom,
  }) async {
    if (await _db.isBlocked(peerId)) {
      throw StateError('User is blocked');
    }

    final conversation = await _conversations.getOrCreate(peerId, peerName);
    final now = DateTime.now();
    final messageId = _uuid.v4();
    final expires = _settings.disappearing24h
        ? now.add(const Duration(hours: 24))
        : null;

    final message = Message(
      id: messageId,
      conversationId: conversation.id,
      body: body,
      isOutgoing: true,
      status: MessageStatus.pending,
      type: type,
      createdAt: now,
      replyToId: replyToId,
      forwardedFrom: forwardedFrom,
      expiresAt: expires,
    );

    await _messages.save(message);
    await _conversations.updatePreview(
      conversation.id,
      lastMessage: preview.isEmpty ? body : preview,
    );
    _messageEvents.add(message);

    payload['id'] = messageId;
    payload['timestamp'] = now.millisecondsSinceEpoch;
    if (replyToId != null) payload['reply_to_id'] = replyToId;
    if (forwardedFrom != null) payload['forwarded_from'] = forwardedFrom;
    if (expires != null) {
      payload['expires_at'] = expires.millisecondsSinceEpoch;
    }

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

  Future<void> retryMessage(
    Message message,
    String peerId,
    String peerName,
  ) async {
    if (message.status != MessageStatus.failed) return;
    await _messages.updateStatus(message.id, MessageStatus.pending);

    final payload = <String, dynamic>{
      'id': message.id,
      'timestamp': message.createdAt.millisecondsSinceEpoch,
      'type': message.type.name,
    };

    if (message.type == MessageType.text) {
      payload['body'] = message.body;
    } else {
      final base64 = await _media.readAsBase64(message.body);
      if (base64 == null) return;
      payload['body'] = base64;
    }

    final sent = await _transportSend(peerId, payload);
    if (sent) {
      await _messages.updateStatus(
        message.id,
        MessageStatus.delivered,
        sentAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );
      await _messages.dequeueOutbox(message.id);
      _messageEvents.add(message.copyWith(status: MessageStatus.delivered));
    }
  }

  Future<void> _processOutbox() async {
    final pending = await _db.getPendingOutbox();
    for (final row in pending) {
      final messageId = row['message_id'] as String;
      final peerId = row['peer_id'] as String;
      final msgs = await _messages.getForConversation(peerId);
      final msg = msgs.where((m) => m.id == messageId).firstOrNull;
      if (msg != null) {
        await retryMessage(msg, peerId, peerId);
      } else {
        await _db.bumpOutboxRetry(messageId);
      }
    }
  }

  Future<void> _onBluetoothIncoming(IncomingPacket packet) async {
    final payload = _decrypt(packet.payload);
    if (payload == null) return;
    await _handleEvent(peerId: packet.peerId, payload: payload);
  }

  Future<void> _onTransportEvent(Map<String, dynamic> raw) async {
    final payload = _decrypt(raw);
    if (payload == null) return;

    final type = payload['type'] as String?;
    if (type == 'ping' || type == 'pong' || type == 'hello') return;

    final peerId = _groupChat.isConnected
        ? _groupChat.groupPeerId
        : _codePairing.localPeerId;

    await _handleEvent(peerId: peerId, payload: payload);
  }

  Future<void> _handleEvent({
    required String peerId,
    required Map<String, dynamic> payload,
  }) async {
    final type = payload['type'] as String?;

    switch (type) {
      case 'typing':
        if (payload['active'] == true) {
          _typingController.add(peerId);
        }
        return;
      case 'read':
        final ids = (payload['message_ids'] as List?)?.cast<String>() ?? [];
        for (final id in ids) {
          await _messages.updateStatus(id, MessageStatus.read);
          _messageEvents.add(Message(
            id: id,
            conversationId: peerId,
            body: '',
            isOutgoing: true,
            status: MessageStatus.read,
            createdAt: DateTime.now(),
          ));
        }
        return;
      case 'delete':
        final id = payload['message_id'] as String?;
        if (id != null) await _db.deleteMessage(id);
        return;
      case 'presence':
        final ms = payload['last_seen'] as int?;
        if (ms != null) {
          _lastSeenController.add(DateTime.fromMillisecondsSinceEpoch(ms));
        }
        return;
      case 'call_invite':
      case 'call_accept':
      case 'call_end':
        return;
    }

    if (type == 'text' ||
        type == 'image' ||
        type == 'voice' ||
        type == 'video' ||
        type == 'document') {
      await _handleIncomingMessage(peerId: peerId, payload: payload);
    }
  }

  Future<void> _handleIncomingMessage({
    required String peerId,
    required Map<String, dynamic> payload,
  }) async {
    if (await _db.isBlocked(peerId)) return;

    final typeStr = payload['type'] as String? ?? 'text';
    final messageId = payload['id'] as String? ?? _uuid.v4();
    final timestamp = payload['timestamp'] as int?;
    final replyToId = payload['reply_to_id'] as String?;
    final forwardedFrom = payload['forwarded_from'] as String?;
    final expiresMs = payload['expires_at'] as int?;

    var body = payload['body'] as String? ?? '';
    MessageType msgType = MessageType.text;

    switch (typeStr) {
      case 'image':
        msgType = MessageType.image;
        body = await _media.saveIncomingBase64(body, '.jpg') ?? body;
      case 'voice':
        msgType = MessageType.voice;
        body = await _media.saveIncomingBase64(body, '.m4a') ?? body;
      case 'video':
        msgType = MessageType.video;
        body = await _media.saveIncomingBase64(body, '.mp4') ?? body;
      case 'document':
        msgType = MessageType.document;
        final name = payload['filename'] as String? ?? 'file.bin';
        body = await _media.saveIncomingBase64(body, p.extension(name)) ?? body;
    }

    final preview = switch (msgType) {
      MessageType.image => '📷 Photo',
      MessageType.voice => '🎤 Voice',
      MessageType.video => '🎬 Video',
      MessageType.document => '📄 Document',
      _ => body,
    };

    final peerName = _codePairing.connectedPeerName ?? peerId;
    final conversation = await _conversations.getOrCreate(peerId, peerName);

    final message = Message(
      id: messageId,
      conversationId: conversation.id,
      body: body,
      isOutgoing: false,
      status: MessageStatus.delivered,
      type: msgType,
      createdAt: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.now(),
      deliveredAt: DateTime.now(),
      replyToId: replyToId,
      forwardedFrom: forwardedFrom,
      expiresAt: expiresMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
          : null,
    );

    await _messages.save(message);
    await _conversations.updatePreview(
      conversation.id,
      lastMessage: preview,
      incrementUnread: true,
    );
    _messageEvents.add(message);

    if (_settings.vibrateEnabled && !Platform.isWindows) {
      try {
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 80);
        }
      } catch (_) {}
    }

    await NotificationService.instance.showMessage(
      title: peerName,
      body: preview,
      peerId: peerId,
    );

    await sendReadReceipt(peerId, [messageId]);
  }

  Future<void> broadcastPresence() async {
    final now = DateTime.now();
    await _settings.setMyLastSeen(now);
    if (_codePairing.isConnected) {
      await _transportSend(_codePairing.localPeerId, {
        'type': 'presence',
        'last_seen': now.millisecondsSinceEpoch,
      });
    }
  }

  Future<void> saveContact(SavedContact contact) => _db.saveContact(contact);

  Future<List<SavedContact>> getContacts() => _db.getContacts();

  Future<void> postStatus(String body,
      {String type = 'text', String? mediaPath}) async {
    final now = DateTime.now();
    await _db.saveStatus(StatusStory(
      id: _uuid.v4(),
      body: body,
      type: type,
      mediaPath: mediaPath,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    ));
  }

  Future<List<StatusStory>> getStatuses() => _db.getActiveStatuses();

  Future<String> exportBackup() => _db.exportBackupJson();

  Future<void> importBackup(String json) => _db.importBackupJson(json);

  Future<void> dispose() async {
    await _incomingSub?.cancel();
    await _codeSub?.cancel();
    await _groupSub?.cancel();
    _outboxTimer?.cancel();
    _expiryTimer?.cancel();
    _typingTimer?.cancel();
    await _messageEvents.close();
    await _typingController.close();
    await _lastSeenController.close();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
