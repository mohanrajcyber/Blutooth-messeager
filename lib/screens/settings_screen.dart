import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/settings_providers.dart';
import '../services/security/encryption_service.dart';
import '../services/settings/settings_service.dart';
import 'backup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsServiceProvider);
    final name = ref.watch(displayNameProvider);
    final strings = settings.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          _header('Profile'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(name),
            subtitle: const Text('Display name & avatar'),
            onTap: () => _editName(context, ref, name),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Profile photo'),
            onTap: () async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (file != null) {
                await settings.setProfileAvatar(file.path);
              }
            },
          ),
          _header('Appearance'),
          RadioListTile<AppThemeMode>(
            title: Text(strings.lightTheme),
            value: AppThemeMode.light,
            groupValue: themeMode,
            onChanged: (v) => saveThemeMode(ref, v!),
          ),
          RadioListTile<AppThemeMode>(
            title: Text(strings.darkTheme),
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
          ListTile(
            title: const Text('Bubble color'),
            subtitle: Text(settings.bubbleColor ?? 'Default green'),
            onTap: () async {
              await settings.setBubbleColor('#25D366');
            },
          ),
          ListTile(
            title: const Text('Chat wallpaper'),
            onTap: () async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (file != null) {
                await settings.setChatWallpaper(file.path);
              }
            },
          ),
          _header(strings.language),
          SwitchListTile(
            title: const Text('Tamil UI'),
            value: settings.strings.code == 'ta',
            onChanged: (v) async {
              await settings.setLanguage(v ? 'ta' : 'en');
              ref.read(themeRefreshProvider.notifier).state++;
            },
          ),
          _header('Privacy & security'),
          SwitchListTile(
            title: Text(strings.appLock),
            subtitle: const Text('PIN + fingerprint'),
            value: settings.lockEnabled,
            onChanged: (v) async {
              if (v) {
                final pin = await _askPin(context);
                if (pin != null) {
                  await settings.setPinHash(EncryptionService.hashPin(pin));
                  await settings.setLockEnabled(true);
                }
              } else {
                await settings.setLockEnabled(false);
                await settings.setPinHash(null);
              }
            },
          ),
          SwitchListTile(
            title: Text(strings.disappearing),
            value: settings.disappearing24h,
            onChanged: (v) => settings.setDisappearing24h(v),
          ),
          SwitchListTile(
            title: const Text('Message sound'),
            value: settings.soundEnabled,
            onChanged: settings.setSoundEnabled,
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            value: settings.vibrateEnabled,
            onChanged: settings.setVibrateEnabled,
          ),
          const ListTile(
            leading: Icon(Icons.enhanced_encryption),
            title: Text('End-to-end encryption'),
            subtitle: Text('Enabled on code/WiFi connections'),
          ),
          _header('Data'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: Text(strings.backup),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
          _header('About'),
          ListTile(
            leading: const Icon(Icons.wifi_off),
            title: Text(strings.noInternet),
            subtitle: const Text('Bluetooth or local WiFi/hotspot only'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('BT Messenger v0.3.0'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPin(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set PIN'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
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
        content: TextField(controller: controller, autofocus: true),
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

class _header extends StatelessWidget {
  const _header(this.title);
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
        ),
      ),
    );
  }
}
