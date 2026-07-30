import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications on Android/iOS; log-only on desktop.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _foregroundPeerId;

  void setForegroundChat(String? peerId) => _foregroundPeerId = peerId;

  Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      _ready = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _ready = true;
  }

  Future<void> showMessage({
    required String title,
    required String body,
    String? peerId,
  }) async {
    if (!_ready) return;
    if (peerId != null && peerId == _foregroundPeerId) return;

    if (!(Platform.isAndroid || Platform.isIOS)) {
      debugPrint('Notification: $title — $body');
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'bt_messages',
        'Messages',
        channelDescription: 'New chat messages',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      peerId?.hashCode ?? title.hashCode,
      title,
      body,
      details,
    );
  }
}
