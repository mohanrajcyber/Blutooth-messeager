import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/peer.dart';
import '../providers/app_providers.dart';
import '../services/bluetooth/bluetooth_service.dart';
import 'chat_screen.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bluetoothServiceProvider).startDiscovery();
    });
  }

  @override
  void dispose() {
    ref.read(bluetoothServiceProvider).stopDiscovery();
    super.dispose();
  }

  Future<void> _openChat(Peer peer) async {
    final bluetooth = ref.read(bluetoothServiceProvider);
    await bluetooth.stopDiscovery();

    try {
      await bluetooth.connect(peer);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect — try moving closer'),
          ),
        );
      }
    }

    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: peer.id,
          peerName: peer.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(nearbyPeersProvider);
    final connection = ref.watch(connectionStateProvider);
    final bluetooth = ref.watch(bluetoothServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(bluetoothServiceProvider).startDiscovery();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          connection.when(
            data: (state) {
              if (state == BluetoothConnectionState.scanning) {
                return const LinearProgressIndicator(
                  backgroundColor: AppColors.divider,
                  color: AppColors.accent,
                );
              }

              if (state == BluetoothConnectionState.error) {
                return Material(
                  color: Colors.red.shade700,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      bluetooth.isAdapterOn
                          ? 'Scan failed — turn on Bluetooth in Windows Settings'
                          : 'Bluetooth is off — enable it in Settings → Bluetooth',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                );
              }

              if (state == BluetoothConnectionState.idle) {
                return Material(
                  color: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set PC Bluetooth name to: ${bluetooth.advertiseName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Settings → Bluetooth → Rename this PC',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: peers.when(
              data: (items) {
                final isScanning = connection.maybeWhen(
                  data: (s) => s == BluetoothConnectionState.scanning,
                  orElse: () => false,
                );

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isScanning
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth_disabled,
                            size: 72,
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isScanning
                                ? 'Searching for nearby users…'
                                : 'No devices found',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isScanning
                                ? 'Both devices must open BT Messenger and stay on this screen'
                                : 'Use two PCs or a phone + PC with Bluetooth on.\nSame PC-ல two apps discover ஆகாது.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.subtitle),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final peer = items[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          peer.name.isNotEmpty
                              ? peer.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        peer.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        peer.rssi != null
                            ? 'Signal: ${peer.rssi} dBm'
                            : peer.deviceId,
                        style: const TextStyle(color: AppColors.subtitle),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openChat(peer),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
