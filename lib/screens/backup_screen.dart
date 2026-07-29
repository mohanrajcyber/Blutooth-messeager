import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/app_providers.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final service = await ref.read(messageServiceProvider.future);
                final json = await service.exportBackup();
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup copied to clipboard')),
                  );
                }
              },
              icon: const Icon(Icons.upload),
              label: const Text('Export backup (copy)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text == null) return;
                final service = await ref.read(messageServiceProvider.future);
                await service.importBackup(data!.text!);
                ref.read(messageRefreshProvider.notifier).state++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restored')),
                  );
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Import from clipboard'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final service = await ref.read(messageServiceProvider.future);
                final json = await service.exportBackup();
                final dir = await getApplicationDocumentsDirectory();
                final file = File('${dir.path}/bt_backup.json');
                await file.writeAsString(json);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved: ${file.path}')),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save backup file'),
            ),
          ],
        ),
      ),
    );
  }
}
