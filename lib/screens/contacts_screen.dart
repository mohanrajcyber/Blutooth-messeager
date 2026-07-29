import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/contact.dart';
import '../providers/app_providers.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  List<SavedContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = await ref.read(messageServiceProvider.future);
    final items = await service.getContacts();
    if (mounted) setState(() => _contacts = items);
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(hintText: 'Code MOB-XXXX'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final service = await ref.read(messageServiceProvider.future);
    await service.saveContact(SavedContact(
      id: const Uuid().v4(),
      name: nameCtrl.text.trim(),
      code: codeCtrl.text.trim().toUpperCase(),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addContact),
        ],
      ),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (_, i) {
          final c = _contacts[i];
          return ListTile(
            leading: CircleAvatar(child: Text(c.name[0].toUpperCase())),
            title: Text(c.name),
            subtitle: Text(c.code),
            trailing: IconButton(
              icon: const Icon(Icons.link),
              onPressed: () async {
                final encryption = ref.read(encryptionServiceProvider);
                ref.read(codePairingServiceProvider).setOutgoingSessionKey(
                      encryption.generateSessionKey(),
                    );
                await ref
                    .read(codePairingServiceProvider)
                    .connectToCode(c.code);
              },
            ),
          );
        },
      ),
    );
  }
}
