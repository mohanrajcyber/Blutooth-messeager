import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/peer.dart';
import '../providers/app_providers.dart';
import '../services/bluetooth/bluetooth_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
  });

  final String peerId;
  final String peerName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _connectAndMarkRead();
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
    } catch (_) {
      // Peer may be out of range — local history still works
    }

    final conv = await ref
        .read(conversationRepositoryProvider)
        .getByPeerId(widget.peerId);
    if (conv != null) {
      await ref.read(conversationRepositoryProvider).markRead(conv.id);
      ref.read(messageRefreshProvider.notifier).state++;
    }
  }

  Future<void> _sendMessage(String text) async {
    final service = await ref.read(messageServiceProvider.future);
    await service.sendText(
      peerId: widget.peerId,
      peerName: widget.peerName,
      text: text,
    );
    ref.read(messageRefreshProvider.notifier).state++;

    await Future.delayed(const Duration(milliseconds: 50));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
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
    final connection = ref.watch(connectionStateProvider);
    final connected = connection.maybeWhen(
      data: (state) => state == BluetoothConnectionState.connected,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName),
            Text(
              connected ? 'online via Bluetooth' : 'offline',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.chatBackground,
              ),
              child: messages.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'Messages travel over Bluetooth\nNo internet required',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.subtitle),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: items[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
          ChatInputBar(onSend: _sendMessage),
        ],
      ),
    );
  }
}
