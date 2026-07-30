import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/peer.dart';
import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../services/bluetooth/bluetooth_service.dart';
import 'chat_screen.dart';
import 'connect_by_code_screen.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  bool _showAllDevices = true;

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
            '"${peer.name}" is a normal Bluetooth device (TV, speaker, etc.).\n\n'
            'For messaging, pick a device with the green BT Messenger badge, '
            'or use Connect by code (WiFi/hotspot).',
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
      SnackBar(content: Text('Pairing with ${peer.name}…')),
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

      ref.read(activeSessionProvider.notifier).state = ActiveSession(
        peerId: peer.id,
        peerName: peer.name,
        viaCode: false,
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

  Widget _statusBanner(
    BluetoothService bluetooth,
    AsyncValue<BluetoothConnectionState> connection,
  ) {
    final isScanning = connection.maybeWhen(
      data: (s) => s == BluetoothConnectionState.scanning,
      orElse: () => false,
    );
    final hasError = connection.maybeWhen(
      data: (s) => s == BluetoothConnectionState.error,
      orElse: () => false,
    );

    if (isScanning) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(
            backgroundColor: AppColors.divider,
            color: AppColors.accent,
          ),
          Material(
            color: AppColors.primary.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_searching, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scanning all Bluetooth devices… (${bluetooth.discoveredCount} found)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (hasError) {
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

    final isWindows = Platform.isWindows;
    final advertising = bluetooth.isAdvertising;
    final advertiseError = bluetooth.advertiseError;

    Color bannerColor;
    if (advertising) {
      bannerColor = AppColors.primary;
    } else if (isWindows) {
      bannerColor = Colors.orange.shade800;
    } else {
      bannerColor = AppColors.primary.withValues(alpha: 0.85);
    }

    return Material(
      color: bannerColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  advertising ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    advertising
                        ? 'Visible as: ${bluetooth.advertiseName}'
                        : isWindows
                            ? 'PC scan mode — phone should scan for this PC'
                            : 'Starting Bluetooth visibility…',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              advertising
                  ? 'Tap a BT Messenger device below, then Pair & Chat.'
                  : isWindows
                      ? 'Windows BLE advertise limited. Open BT Messenger on phone → '
                        'Bluetooth scan. Or use Connect by code (works best).'
                      : 'Keep Bluetooth ON. Green badge = BT Messenger app.',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (!advertising && advertiseError != null) ...[
              const SizedBox(height: 6),
              Text(
                'Advertise: ${advertiseError.length > 80 ? '${advertiseError.substring(0, 80)}…' : advertiseError}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
            if (!advertising) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      ref.read(bluetoothServiceProvider).retryAdvertising();
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry visibility', style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ConnectByCodeScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code, size: 16),
                    label: const Text('Connect by code', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _peerTile(Peer peer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: peer.isMessenger
          ? AppColors.accent.withValues(alpha: 0.08)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: peer.isMessenger
              ? AppColors.accent.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Icon(
            peer.isMessenger ? Icons.chat : Icons.bluetooth,
            color: peer.isMessenger ? AppColors.accent : AppColors.primary,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          style: const TextStyle(color: AppColors.subtitle, fontSize: 12),
        ),
        trailing: peer.isMessenger
            ? FilledButton(
                onPressed: () => _selectDevice(peer),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Pair & Chat'),
              )
            : TextButton(
                onPressed: () => _selectDevice(peer),
                child: const Text('Connect'),
              ),
        onTap: () => _selectDevice(peer),
      ),
    );
  }

  Widget _sectionHeader(String title, {int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.subtitle,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.subtitle.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
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
            icon: Icon(
              _showAllDevices ? Icons.filter_list : Icons.filter_list_off,
            ),
            tooltip: _showAllDevices ? 'Hide other devices' : 'Show all devices',
            onPressed: () => setState(() => _showAllDevices = !_showAllDevices),
          ),
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
            tooltip: 'Rescan',
            onPressed: () {
              ref.read(bluetoothServiceProvider).rescan();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          connection.when(
            data: (_) => _statusBanner(bluetooth, connection),
            loading: () => _statusBanner(bluetooth, connection),
            error: (_, __) => _statusBanner(bluetooth, connection),
          ),
          Expanded(
            child: peers.when(
              data: (items) {
                final sorted = _sortedPeers(items);
                final messenger = sorted.where((p) => p.isMessenger).toList();
                final others =
                    sorted.where((p) => !p.isMessenger).toList();

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
                                ? 'Scanning Bluetooth devices…'
                                : 'No devices found',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isScanning
                                ? 'Phone-la BT Messenger open pannunga → Bluetooth scan.\n'
                                  'PC-la same screen open irukkanum.'
                                : 'Bluetooth pair aagala? Connect by code use pannunga (hotspot).',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.subtitle),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () {
                              ref.read(bluetoothServiceProvider).startDiscovery();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan again'),
                          ),
                          const SizedBox(height: 10),
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
                      ),
                    ),
                  );
                }

                return ListView(
                  children: [
                    _sectionHeader('BT Messenger devices', count: messenger.length),
                    if (messenger.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          Platform.isWindows
                              ? 'Phone-la app open pannitu scan pannunga — '
                                'PC BT advertise Windows-la limit aagum.'
                              : 'Open BT Messenger on the other phone/PC and wait…',
                          style: const TextStyle(
                            color: AppColors.subtitle,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...messenger.map(_peerTile),
                    if (_showAllDevices && others.isNotEmpty) ...[
                      _sectionHeader('Other Bluetooth devices', count: others.length),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'TV, speaker maari devices — messaging ku BT Messenger badge venum.',
                          style: TextStyle(
                            color: AppColors.subtitle.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ...others.map(_peerTile),
                    ],
                    const SizedBox(height: 16),
                  ],
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
