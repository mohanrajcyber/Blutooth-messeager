import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/settings_providers.dart';
import '../services/security/encryption_service.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _pinCtrl = TextEditingController();
  final _auth = LocalAuthentication();

  Future<void> _tryBiometric() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock BT Messenger',
      );
      if (ok) widget.onUnlocked();
    } catch (_) {}
  }

  Future<void> _tryPin() async {
    final settings = ref.read(settingsServiceProvider);
    final hash = settings.pinHash;
    if (hash == null) return;
    if (EncryptionService.hashPin(_pinCtrl.text) == hash) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64),
              const SizedBox(height: 16),
              const Text('App locked'),
              const SizedBox(height: 24),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Enter PIN'),
                onSubmitted: (_) => _tryPin(),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _tryPin, child: const Text('Unlock')),
              TextButton(
                onPressed: _tryBiometric,
                child: const Text('Use fingerprint'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
