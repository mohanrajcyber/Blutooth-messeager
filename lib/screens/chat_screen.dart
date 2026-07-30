import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/settings_providers.dart';
import '../services/notifications/notification_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/whatsapp_chat_background.dart';
import 'call_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.viaCode,
    this.embedded = false,
  });

  final String peerId;
  final String peerName;
  final bool? viaCode;
  final bool embedded;

  bool get isCodeChat =>
      viaCode ?? peerId.startsWith(AppConstants.localPeerPrefix);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  Message? _replyTo;
  bool _searching = false;
  String? _typingPeer;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.setForegroundChat(widget.peerId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeSessionProvider.notifier).state = ActiveSession(
        peerId: widget.peerId,
        peerName: widget.peerName,
        viaCode: widget.isCodeChat,
      );
      _markReadAndConnect();
      _listenTyping();
    });
  }

  void _listenTyping() {
    ref.read(messageServiceProvider.future).then((service) {
      service.typingStream.listen((peer) {
        if (mounted && peer == widget.peerId) {
          setState(() => _typingPeer = peer);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _typingPeer = null);
          });
        }
      });
    });
  }

  Future<void> _markReadAndConnect() async {
    final conv = await ref
        .read(conversationRepositoryProvider)
        .getByPeerId(widget.peerId);
    if (conv != null) {
      await ref.read(conversationRepositoryProvider).markRead(conv.id);
      ref.read(messageRefreshProvider.notifier).state++;
    }
    if (!widget.isCodeChat) {
      try {
        await ref.read(bluetoothServiceProvider).connect(
              Peer(
                id: widget.peerId,
                name: widget.peerName,
                deviceId: widget.peerId,
              ),
            );
      } catch (_) {}
    }
    final service = await ref.read(messageServiceProvider.future);
    await service.broadcastPresence();
  }

  Future<void> _sendMessage(String text) async {
    final service = await ref.read(messageServiceProvider.future);
    await service.sendText(
      peerId: widget.peerId,
      peerName: widget.peerName,
      text: text,
      replyToId: _replyTo?.id,
    );
    setState(() => _replyTo = null);
    ref.read(messageRefreshProvider.notifier).state++;
    _scrollToBottom();
  }

  Future<void> _sendImage(ImageSource source) async {
    final service = await ref.read(messageServiceProvider.future);
    final path = await service.media.pickImage(source);
    if (path == null) return;
    await service.sendMedia(
      peerId: widget.peerId,
      peerName: widget.peerName,
      filePath: path,
      type: MessageType.image,
      mime: 'image/jpeg',
    );
    ref.read(messageRefreshProvider.notifier).state++;
    _scrollToBottom();
  }

  Future<void> _sendVideo() async {
    final service = await ref.read(messageServiceProvider.future);
    final path = await service.media.pickVideo();
    if (path == null) return;
    await service.sendMedia(
      peerId: widget.peerId,
      peerName: widget.peerName,
      filePath: path,
      type: MessageType.video,
      mime: 'video/mp4',
    );
    ref.read(messageRefreshProvider.notifier).state++;
  }

  Future<void> _sendDocument() async {
    final service = await ref.read(messageServiceProvider.future);
    final path = await service.media.pickDocument();
    if (path == null) return;
    await service.sendMedia(
      peerId: widget.peerId,
      peerName: widget.peerName,
      filePath: path,
      type: MessageType.document,
      mime: 'application/octet-stream',
    );
    ref.read(messageRefreshProvider.notifier).state++;
  }

  Future<void> _onVoiceStop() async {
    final service = await ref.read(messageServiceProvider.future);
    final path = await service.media.stopVoiceRecord();
    if (path == null) return;
    await service.sendMedia(
      peerId: widget.peerId,
      peerName: widget.peerName,
      filePath: path,
      type: MessageType.voice,
      mime: 'audio/m4a',
    );
    ref.read(messageRefreshProvider.notifier).state++;
  }

  void _onTyping() {
    ref.read(messageServiceProvider.future).then((s) {
      s.sendTyping(widget.peerId, active: true);
    });
  }

  Future<void> _retryMessage(String messageId) async {
    final service = await ref.read(messageServiceProvider.future);
    final msgs = await ref
        .read(messageRepositoryProvider)
        .getForConversation(widget.peerId);
    final msg = msgs.where((m) => m.id == messageId).firstOrNull;
    if (msg != null) {
      await service.retryMessage(msg, widget.peerId, widget.peerName);
      ref.read(messageRefreshProvider.notifier).state++;
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _messageActions(Message message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(ctx, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(ctx, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete for me'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete for everyone'),
              onTap: () => Navigator.pop(ctx, 'delete_all'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final service = await ref.read(messageServiceProvider.future);

    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
      case 'reply':
        setState(() => _replyTo = message);
      case 'forward':
        await service.sendText(
          peerId: widget.peerId,
          peerName: widget.peerName,
          text: message.body,
          forwardedFrom: message.id,
        );
        ref.read(messageRefreshProvider.notifier).state++;
      case 'delete':
        await service.sendDelete(widget.peerId, message.id, forAll: false);
        ref.read(messageRefreshProvider.notifier).state++;
      case 'delete_all':
        await service.sendDelete(widget.peerId, message.id, forAll: true);
        ref.read(messageRefreshProvider.notifier).state++;
    }
  }

  Future<void> _showMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search'),
              onTap: () => Navigator.pop(ctx, 'search'),
            ),
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Voice call'),
              onTap: () => Navigator.pop(ctx, 'voice'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video call'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block user'),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Disconnect'),
              onTap: () => Navigator.pop(ctx, 'disconnect'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Exit app'),
              onTap: () => Navigator.pop(ctx, 'exit'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'search':
        setState(() => _searching = !_searching);
      case 'voice':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              peerId: widget.peerId,
              peerName: widget.peerName,
            ),
          ),
        );
      case 'video':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              peerId: widget.peerId,
              peerName: widget.peerName,
              isVideo: true,
            ),
          ),
        );
      case 'block':
        await ref.read(appDatabaseProvider).blockUser(widget.peerId);
        if (mounted) Navigator.pop(context);
      case 'settings':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case 'disconnect':
        ref.read(activeSessionProvider.notifier).state = null;
        if (widget.embedded) {
          ref.read(selectedChatProvider.notifier).state = null;
        } else if (mounted) {
          Navigator.pop(context);
        }
      case 'exit':
        await SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    NotificationService.instance.setForegroundChat(null);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = _searching && _searchCtrl.text.isNotEmpty
        ? ref.watch(searchMessagesProvider(
            (widget.peerId, _searchCtrl.text),
          ))
        : ref.watch(messagesProvider(widget.peerId));
    final online = ref.watch(peerOnlineProvider(widget.peerId));
    final isCode = widget.isCodeChat;
    final strings = ref.watch(settingsServiceProvider).strings;

    var statusText = online
        ? (isCode
            ? '${strings.online} · ${strings.noInternet}'
            : '${strings.online} · Bluetooth')
        : strings.offline;
    if (_typingPeer != null) statusText = strings.typing;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(widget.peerName[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.peerName, overflow: TextOverflow.ellipsis),
                  Text(statusText,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: strings.search,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (_replyTo != null)
            Material(
              color: AppColors.primary.withValues(alpha: 0.1),
              child: ListTile(
                dense: true,
                title: Text('Reply: ${_replyTo!.body}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _replyTo = null),
                ),
              ),
            ),
          Expanded(
            child: WhatsAppChatBackground(
              child: messagesAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        '${strings.noInternet}\n🔒 Local chat only',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: chatTheme(context).subtitle),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final message = items[index];
                      String? replyPreview;
                      if (message.replyToId != null) {
                        final orig = items
                            .where((m) => m.id == message.replyToId)
                            .firstOrNull;
                        replyPreview = orig?.body;
                      }
                      return ChatBubble(
                        key: ValueKey(message.id),
                        message: message,
                        replyPreview: replyPreview,
                        onRetry: message.status == MessageStatus.failed
                            ? () => _retryMessage(message.id)
                            : null,
                        onLongPress: () => _messageActions(message),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
          ChatInputBar(
            enabled: online || isCode,
            onSend: _sendMessage,
            onImagePicked: _sendImage,
            onVideoPicked: _sendVideo,
            onDocumentPicked: _sendDocument,
            onVoiceStart: () {
              ref.read(messageServiceProvider.future).then((s) {
                s.media.startVoiceRecord();
              });
            },
            onVoiceStop: _onVoiceStop,
            onTyping: _onTyping,
          ),
        ],
      ),
    );
  }
}

final searchMessagesProvider = FutureProvider.family<List<Message>,
    (String, String)>((ref, params) async {
  ref.watch(messageRefreshProvider);
  return ref.watch(appDatabaseProvider).searchMessages(params.$1, params.$2);
});

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
