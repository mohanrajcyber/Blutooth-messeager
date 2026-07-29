import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../providers/app_providers.dart';
import '../services/bluetooth/bluetooth_service.dart';

class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionStateProvider);

    return state.when(
      data: (connectionState) {
        final (text, color) = switch (connectionState) {
          BluetoothConnectionState.scanning => (
              'Scanning for nearby devices…',
              AppColors.primary,
            ),
          BluetoothConnectionState.connecting => (
              'Connecting…',
              AppColors.primary,
            ),
          BluetoothConnectionState.connected => (
              'Connected via Bluetooth',
              AppColors.accent,
            ),
          BluetoothConnectionState.error => (
              ref.watch(bluetoothServiceProvider).isAdapterOn
                  ? 'Bluetooth unavailable — check Settings'
                  : 'Turn on Bluetooth in Windows Settings',
              Colors.red.shade700,
            ),
          BluetoothConnectionState.idle => (null, Colors.transparent),
        };

        if (text == null) return const SizedBox.shrink();

        return Material(
          color: color,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                if (connectionState == BluetoothConnectionState.scanning)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                if (connectionState == BluetoothConnectionState.scanning)
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
