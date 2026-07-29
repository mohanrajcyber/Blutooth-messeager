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
import '../services/bluetooth/bluetooth_service.dart';
import '../services/media/image_message_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/whatsapp_chat_background.dart';
import 'settings_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    bool? viaCode,
  }) : viaCode = viaCode;

  final String peerId;
  final String peerName;
  final bool? viaCode;

  bool get isCodeChat =>
      viaCode ?? peerId.startsWith(AppConstants.localPeerPrefix);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _images = ImageMessageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeSessionProvider.notifier).state = ActiveSession(
        peerId: widget.peerId,
        peerName: widget.peerName,
        viaCode: widget.isCodeChat,
      );
      if (widget.isCodeChat) {
        _markReadOnly();
      } else {
        _connectAndMarkRead();
      }
    });
  }

  Future<void> _markReadOnly() async {
    final conv = await ref
        .read(conversationRepositoryProvider)
        .getByPeerId(widget.peerId);
    if (conv != null) {
      await ref.read(conversationRepositoryProvider).markRead(conv.id);
      ref.read(messageRefreshProvider.notifier).state++;
    }
  }

  Future<void> _connectAndMarkRead() async {
    final bluetooth = ref.read(bluetoothServiceProvider);
    final peer = Peer(
      id: widget.peerId,
      name: widget.peerName,
      deviceId: widget.peerId,
    );

    try {
      await bluetooth.connect(peer);
    } catch (_) {}

    await _markReadOnly();
  }

  Future<void> _sendMessage(String text) async {
    final service = await ref.read(messageServiceProvider.future);
    await service.sendText(
      peerId: widget.peerId,
      peerName: widget.peerName,
      text: text,
    );
    ref.read(messageRefreshProvider.notifier).state++;
    _scrollToBottom();
  }

  Future<void> _sendImage(ImageSource source) async {
    try {
      final path = await _images.pickAndSave(source: source);
      if (path == null || !mounted) return;

      final service = await ref.read(messageServiceProvider.future);
      await service.sendImage(
        peerId: widget.peerId,
        peerName: widget.peerName,
        imagePath: path,
      );
      ref.read(messageRefreshProvider.notifier).state++;
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _retryMessage(String messageId) async {
    final messages =
        await ref.read(messageRepositoryProvider).getForConversation(
              widget.peerId,
            );
    final message = messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null) return;

    final service = await ref.read(messageServiceProvider.future);
    await service.retryMessage(message, widget.peerId, widget.peerName);
    ref.read(messageRefreshProvider.notifier).state++;
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

  Future<void> _showMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear chat'),
              onTap: () => Navigator.pop(ctx, 'clear'),
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
      case 'settings':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case 'disconnect':
        ref.read(activeSessionProvider.notifier).state = null;
        if (mounted) Navigator.of(context).pop();
      case 'clear':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history kept on device')),
        );
      case 'exit':
        await SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.peerId));
    final online = ref.watch(peerOnlineProvider(widget.peerId));
    final isCode = widget.isCodeChat;

    String statusText;
    if (online) {
      statusText = isCode
          ? 'online · no internet · WiFi/hotspot'
          : 'online · Bluetooth';
    } else if (isCode) {
      statusText = 'connecting… keep hotspot ON';
    } else {
      statusText = 'offline';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Text(
                    widget.peerName.isNotEmpty
                        ? widget.peerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.headerBackground),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
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
          Expanded(
            child: WhatsAppChatBackground(
              child: messages.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isCode
                              ? '🔒 End-to-end local chat\nNo internet · WiFi/hotspot only'
                              : '📶 Bluetooth chat\nNo internet required',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: chatTheme(context).subtitle,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final message = items[index];
                      return ChatBubble(
                        key: ValueKey(message.id),
                        message: message,
                        onRetry: message.status == MessageStatus.failed
                            ? () => _retryMessage(message.id)
                            : null,
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
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
