import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'screens/chats_screen.dart';

class BluetoothMessengerApp extends ConsumerWidget {
  const BluetoothMessengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BT Messenger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const ChatsScreen(),
    );
  }
}
