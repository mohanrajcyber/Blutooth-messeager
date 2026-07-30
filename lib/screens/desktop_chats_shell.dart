import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/conversation.dart';
import '../providers/connection_providers.dart';
import '../widgets/connection_banner.dart';
import '../widgets/conversation_tile.dart';
import 'chat_screen.dart';

/// WhatsApp Web-style split view: chat list left, active chat right.
class DesktopChatsShell extends ConsumerWidget {
  const DesktopChatsShell({
    super.key,
    required this.conversations,
    required this.onConnect,
    required this.onMenu,
    required this.sessionSubtitle,
  });

  final AsyncValue<List<Conversation>> conversations;
  final VoidCallback onConnect;
  final void Function(String) onMenu;
  final String sessionSubtitle;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedChatProvider);
    final subtitle = chatTheme(context).subtitle;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 380,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  _SidebarHeader(
                    subtitle: sessionSubtitle,
                    onConnect: onConnect,
                    onMenu: onMenu,
                  ),
                  const ConnectionBanner(),
                  Expanded(
                    child: conversations.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 56,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.35),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('No chats yet'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap + to connect',
                                    style: TextStyle(color: subtitle),
                                  ),
                                ],
                              ),
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
                            final online = ref.watch(
                              peerOnlineProvider(conversation.peerId),
                            );
                            final isSelected =
                                selected?.peerId == conversation.peerId;

                            return Material(
                              color: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.12)
                                  : null,
                              child: ConversationTile(
                                conversation: conversation,
                                isOnline: online,
                                onTap: () {
                                  ref
                                      .read(selectedChatProvider.notifier)
                                      .state = SelectedChat(
                                    peerId: conversation.peerId,
                                    peerName: conversation.peerName,
                                    viaCode: conversation.peerId.startsWith(
                                      AppConstants.localPeerPrefix,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 80,
                            color: subtitle.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppConstants.appName,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a chat or tap + to connect',
                            style: TextStyle(color: subtitle),
                          ),
                        ],
                      ),
                    ),
                  )
                : ChatScreen(
                    key: ValueKey(selected.peerId),
                    peerId: selected.peerId,
                    peerName: selected.peerName,
                    viaCode: selected.viaCode,
                    embedded: true,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onConnect,
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.subtitle,
    required this.onConnect,
    required this.onMenu,
  });

  final String subtitle;
  final VoidCallback onConnect;
  final void Function(String) onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              tooltip: 'Connect',
              onPressed: onConnect,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: onMenu,
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
      ),
    );
  }
}
