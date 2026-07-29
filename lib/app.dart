import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/settings_providers.dart';
import 'screens/app_lock_screen.dart';
import 'screens/chats_screen.dart';
import 'services/settings/settings_service.dart';

class BluetoothMessengerApp extends ConsumerStatefulWidget {
  const BluetoothMessengerApp({super.key});

  @override
  ConsumerState<BluetoothMessengerApp> createState() =>
      _BluetoothMessengerAppState();
}

class _BluetoothMessengerAppState extends ConsumerState<BluetoothMessengerApp>
    with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final settings = ref.read(settingsServiceProvider);
      if (settings.lockEnabled) setState(() => _locked = true);
    }
  }

  Future<void> _checkLock() async {
    await ref.read(settingsInitProvider.future);
    final settings = ref.read(settingsServiceProvider);
    if (settings.lockEnabled) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
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
      home: _locked
          ? AppLockScreen(onUnlocked: () => setState(() => _locked = false))
          : const ChatsScreen(),
    );
  }
}
