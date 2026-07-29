import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contact.dart';
import '../providers/app_providers.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenScreenState();
}

class _StatusScreenScreenState extends ConsumerState<StatusScreen> {
  List<StatusStory> _items = [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = await ref.read(messageServiceProvider.future);
    final items = await service.getStatuses();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final service = await ref.read(messageServiceProvider.future);
    await service.postStatus(text);
    _ctrl.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status (24h)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'My status…',
                    ),
                  ),
                ),
                IconButton(onPressed: _post, icon: const Icon(Icons.send)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final s = _items[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.circle)),
                  title: Text(s.body),
                  subtitle: Text(
                    'Expires ${s.expiresAt.hour}:${s.expiresAt.minute.toString().padLeft(2, '0')}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
