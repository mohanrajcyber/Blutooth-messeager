import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/settings_providers.dart';
import '../services/settings/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final name = ref.watch(displayNameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Profile'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(name),
            subtitle: const Text('Display name'),
            trailing: const Icon(Icons.edit),
            onTap: () => _editName(context, ref, name),
          ),
          const _SectionHeader('Appearance'),
          RadioListTile<AppThemeMode>(
            title: const Text('Light theme'),
            value: AppThemeMode.light,
            groupValue: themeMode,
            onChanged: (v) => saveThemeMode(ref, v!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Dark theme'),
            value: AppThemeMode.dark,
            groupValue: themeMode,
            onChanged: (v) => saveThemeMode(ref, v!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('System default'),
            value: AppThemeMode.system,
            groupValue: themeMode,
            onChanged: (v) => saveThemeMode(ref, v!),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.wifi_off),
            title: Text('No internet required'),
            subtitle: Text(
              'Messages travel over Bluetooth or local WiFi/hotspot only.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('BT Messenger'),
            subtitle: const Text('v0.2.0 · Offline messaging'),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await saveDisplayName(ref, result);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: chatTheme(context).subtitle,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
