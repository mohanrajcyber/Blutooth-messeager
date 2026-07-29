import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/settings_providers.dart';
import 'screens/chats_screen.dart';
import 'services/settings/settings_service.dart';

class BluetoothMessengerApp extends ConsumerWidget {
  const BluetoothMessengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(settingsInitProvider);
    ref.watch(themeRefreshProvider);
    final themeMode = ref.watch(themeModeProvider);

    ThemeMode mode;
    switch (themeMode) {
      case AppThemeMode.light:
        mode = ThemeMode.light;
      case AppThemeMode.dark:
        mode = ThemeMode.dark;
      case AppThemeMode.system:
        mode = ThemeMode.system;
    }

    return MaterialApp(
      title: 'BT Messenger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: const ChatsScreen(),
    );
  }
}
