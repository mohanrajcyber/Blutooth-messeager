import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final settingsInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(settingsServiceProvider).init();
});

final themeModeProvider = StateProvider<AppThemeMode>((ref) {
  ref.watch(settingsInitProvider);
  return ref.watch(settingsServiceProvider).themeMode;
});

final displayNameProvider = StateProvider<String>((ref) {
  ref.watch(settingsInitProvider);
  return ref.watch(settingsServiceProvider).displayName;
});

final themeRefreshProvider = StateProvider<int>((ref) => 0);

Future<void> saveThemeMode(WidgetRef ref, AppThemeMode mode) async {
  await ref.read(settingsServiceProvider).setThemeMode(mode);
  ref.read(themeModeProvider.notifier).state = mode;
  ref.read(themeRefreshProvider.notifier).state++;
}

Future<void> saveDisplayName(WidgetRef ref, String name) async {
  await ref.read(settingsServiceProvider).setDisplayName(name);
  ref.read(displayNameProvider.notifier).state = name;
}
