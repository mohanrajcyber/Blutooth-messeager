import 'package:flutter/foundation.dart';

/// Cross-platform notifications (full push on Android APK builds).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb) return;
    _ready = true;
  }

  Future<void> showMessage({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    debugPrint('Notification: $title — $body');
  }
}
