import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/peer.dart';
import '../providers/app_providers.dart';
import '../services/bluetooth/bluetooth_service.dart';
import 'chat_screen.dart';
import 'connect_by_code_screen.dart';

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

  Future<void> _selectDevice(Peer peer) async {
    if (!peer.isMessenger) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not a BT Messenger device'),
          content: Text(
            '"${peer.name}" is a normal Bluetooth device.\n\n'
            'Messaging works only with another BT Messenger app, '
            'or use Connect by code (WiFi/hotspot, no internet).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Try anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${peer.name}…')),
    );

    final bluetooth = ref.read(bluetoothServiceProvider);
    await bluetooth.stopDiscovery();

    try {
      await bluetooth.connect(peer);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paired with ${peer.name}'),
          backgroundColor: AppColors.accent,
        ),
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            peerId: peer.id,
            peerName: peer.name,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            peer.isMessenger
                ? 'Could not connect — try moving closer'
                : 'Cannot message this device. Use Connect by code instead.',
          ),
          action: SnackBarAction(
            label: 'Code',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ConnectByCodeScreen(),
                ),
              );
            },
          ),
        ),
      );
      ref.read(bluetoothServiceProvider).startDiscovery();
    }
  }

  List<Peer> _sortedPeers(List<Peer> items) {
    final copy = List<Peer>.from(items);
    copy.sort((a, b) {
      if (a.isMessenger != b.isMessenger) {
        return a.isMessenger ? -1 : 1;
      }
      final ar = a.rssi ?? -999;
      final br = b.rssi ?? -999;
      return br.compareTo(ar);
    });
    return copy;
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
            icon: const Icon(Icons.qr_code),
            tooltip: 'Connect by code',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ConnectByCodeScreen(),
                ),
              );
            },
          ),
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
                          ? 'Scan failed — turn on Bluetooth in Settings'
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
                          bluetooth.isAdvertising
                              ? 'Visible as: ${bluetooth.advertiseName}'
                              : 'Advertising starting… keep Bluetooth ON',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select a device below. BT Messenger apps show a green badge.',
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
                final sorted = _sortedPeers(items);
                final isScanning = connection.maybeWhen(
                  data: (s) => s == BluetoothConnectionState.scanning,
                  orElse: () => false,
                );

                if (sorted.isEmpty) {
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
                                ? 'Searching for Bluetooth devices…'
                                : 'No devices found',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isScanning
                                ? 'Phone + PC both open this screen. Location ON on phone.'
                                : 'Bluetooth fail? Use Connect by code (hotspot, no internet).',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.subtitle),
                          ),
                          if (!isScanning) ...[
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ConnectByCodeScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.qr_code),
                              label: const Text('Connect by code'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final peer = sorted[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: peer.isMessenger
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.15),
                        child: Icon(
                          peer.isMessenger
                              ? Icons.chat
                              : Icons.bluetooth,
                          color: peer.isMessenger
                              ? AppColors.accent
                              : AppColors.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              peer.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (peer.isMessenger)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'BT Messenger',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        peer.rssi != null
                            ? 'Signal: ${peer.rssi} dBm · ${peer.deviceId}'
                            : peer.deviceId,
                        style: const TextStyle(color: AppColors.subtitle),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectDevice(peer),
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
