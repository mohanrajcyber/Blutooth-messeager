import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'chat_screen.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _hostCode;

  Future<void> _create() async {
    final group = ref.read(groupChatServiceProvider);
    final code = await group.createGroup(name: _nameCtrl.text.trim());
    setState(() => _hostCode = code);
  }

  Future<void> _join() async {
    final group = ref.read(groupChatServiceProvider);
    final ok = await group.joinGroup(_codeCtrl.text.trim(), '192.168.43.1');
    if (!mounted) return;
    if (ok) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            peerId: group.groupPeerId,
            peerName: 'Group ${_codeCtrl.text.trim()}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group chat')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: 'Group name'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _create,
              child: const Text('Create group (host)'),
            ),
            if (_hostCode != null) ...[
              const SizedBox(height: 16),
              Text(
                'Share code: $_hostCode',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const Divider(height: 40),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(hintText: 'GRP-XXXX'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _join, child: const Text('Join group')),
          ],
        ),
      ),
    );
  }
}
