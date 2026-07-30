import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../screens/chat_screen.dart';
import '../screens/desktop_chats_shell.dart';

/// Opens chat after code pairing from any screen (code entry, QR scan, incoming).
class PairingNavigation {
  static DateTime? _lastNav;

  static Future<void> ensureStarted(WidgetRef ref, String displayName) async {
    await ref.read(codePairingServiceProvider).start(displayName: displayName);
  }

  static Future<void> openChatIfPaired(
    BuildContext context,
    WidgetRef ref, {
    bool replace = false,
  }) async {
    final code = ref.read(codePairingServiceProvider);
    if (!code.isPaired || !context.mounted) return;

    final now = DateTime.now();
    if (_lastNav != null &&
        now.difference(_lastNav!) < const Duration(seconds: 2)) {
      return;
    }
    _lastNav = now;

    final peerId = code.localPeerId;
    final peerName =
        code.connectedPeerName ?? code.connectedPeerCode ?? 'Partner';

    ref.read(activeSessionProvider.notifier).state = ActiveSession(
      peerId: peerId,
      peerName: peerName,
      viaCode: true,
    );

    ref.read(selectedChatProvider.notifier).state = SelectedChat(
      peerId: peerId,
      peerName: peerName,
      viaCode: true,
    );

    if (!context.mounted) return;

    if (DesktopChatsShell.isDesktop(context)) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    final route = MaterialPageRoute<void>(
      builder: (_) => ChatScreen(
        peerId: peerId,
        peerName: peerName,
        viaCode: true,
      ),
    );

    if (!context.mounted) return;
    if (replace) {
      await Navigator.of(context).pushReplacement(route);
    } else {
      await Navigator.of(context).push(route);
    }
  }
}
