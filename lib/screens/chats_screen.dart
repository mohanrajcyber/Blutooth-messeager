import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/pairing_navigation.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/settings_providers.dart';
import '../services/notifications/notification_service.dart';
import '../widgets/connection_banner.dart';
import '../widgets/conversation_tile.dart';
import 'desktop_chats_shell.dart';
import 'chat_screen.dart';
import 'connect_by_code_screen.dart';
import 'contacts_screen.dart';
import 'group_chat_screen.dart';
import 'nearby_screen.dart';
import 'qr_connect_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  StreamSubscription<void>? _pairedSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pairedSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await ref.read(settingsInitProvider.future);
    await NotificationService.instance.init();
    final name = ref.read(displayNameProvider);
    final bluetooth = ref.read(bluetoothServiceProvider);
    await bluetooth.initialize(displayName: name);

    // Start code pairing as soon as app opens — required for QR/code sync.
    await PairingNavigation.ensureStarted(ref, name);
    _pairedSub?.cancel();
    _pairedSub = ref.read(codePairingServiceProvider).pairedStream.listen((_) {
      if (mounted) {
        unawaited(PairingNavigation.openChatIfPaired(context, ref));
      }
    });

    final service = await ref.read(messageServiceProvider.future);
    service.messageEvents.listen((_) {
      ref.read(messageRefreshProvider.notifier).state++;
    });
  }

  void _openConnectSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: const Text('Bluetooth scan'),
              subtitle: const Text('Find nearby BT Messenger devices'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const NearbyScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Connect by code'),
              subtitle: const Text('WiFi/hotspot · no internet'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConnectByCodeScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('QR scan connect'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QrConnectScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Group chat'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GroupChatScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Saved contacts'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle),
              title: const Text('Status (24h)'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatusScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMainMenu(String value) async {
    switch (value) {
      case 'settings':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case 'contacts':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ContactsScreen()),
        );
      case 'status':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StatusScreen()),
        );
      case 'name':
        await _showNameDialog();
      case 'exit':
        await SystemNavigator.pop();
    }
  }

  Future<void> _showNameDialog() async {
    final controller = TextEditingController(
      text: ref.read(displayNameProvider),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Your name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await saveDisplayName(ref, result);
      await ref.read(bluetoothServiceProvider).initialize(displayName: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final session = ref.watch(activeSessionProvider);
    final subtitle = chatTheme(context).subtitle;
    final sessionSubtitle = session != null
        ? 'Connected to ${session.peerName}'
        : 'Offline · no internet needed';

    if (DesktopChatsShell.isDesktop(context)) {
      return DesktopChatsShell(
        conversations: conversations,
        onConnect: _openConnectSheet,
        onMenu: _showMainMenu,
        sessionSubtitle: sessionSubtitle,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppConstants.appName),
            Text(
              sessionSubtitle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: _showMainMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'name', child: Text('Display name')),
              PopupMenuItem(value: 'contacts', child: Text('Contacts')),
              PopupMenuItem(value: 'status', child: Text('Status')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'exit', child: Text('Exit app')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: conversations.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 72,
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No chats yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to connect via Bluetooth or code',
                          style: TextStyle(color: subtitle),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 72,
                    color: Theme.of(context).dividerColor,
                  ),
                  itemBuilder: (context, index) {
                    final conversation = items[index];
                    final online =
                        ref.watch(peerOnlineProvider(conversation.peerId));

                    return ConversationTile(
                      conversation: conversation,
                      isOnline: online,
                      onTap: () {
                        ref.read(selectedChatProvider.notifier).state =
                            SelectedChat(
                          peerId: conversation.peerId,
                          peerName: conversation.peerName,
                          viaCode: conversation.peerId.startsWith(
                            AppConstants.localPeerPrefix,
                          ),
                        );
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => ChatScreen(
                              peerId: conversation.peerId,
                              peerName: conversation.peerName,
                            ),
                            transitionsBuilder: (_, anim, __, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openConnectSheet,
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}
