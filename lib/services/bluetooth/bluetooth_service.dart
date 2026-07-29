import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_constants.dart';
import '../../models/peer.dart';

enum BluetoothConnectionState { idle, scanning, connecting, connected, error }

class IncomingPacket {
  IncomingPacket({
    required this.peerId,
    required this.payload,
  });

  final String peerId;
  final Map<String, dynamic> payload;
}

bool get _isBleSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;
}

/// Handles BLE discovery, connection, and binary message transport.
class BluetoothService {
  BluetoothService() {
    if (_isBleSupported) {
      _initBleListeners();
    }
  }

  final _peersController = StreamController<List<Peer>>.broadcast();
  final _incomingController = StreamController<IncomingPacket>.broadcast();
  final _connectionController =
      StreamController<BluetoothConnectionState>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  final Map<String, Peer> _discovered = {};
  final Map<String, BluetoothDevice> _devices = {};
  final Map<String, BluetoothCharacteristic> _writeChars = {};
  final Map<String, StreamSubscription<List<int>>> _notifySubs = {};

  bool _adapterOn = false;
  bool _scanning = false;
  String _displayName = 'User';

  Stream<List<Peer>> get peersStream => _peersController.stream;
  Stream<IncomingPacket> get incomingStream => _incomingController.stream;
  Stream<BluetoothConnectionState> get connectionStream =>
      _connectionController.stream;

  bool get isAdapterOn => _adapterOn;
  bool get isBleSupported => _isBleSupported;

  /// Name other devices should look for in scan results.
  String get advertiseName {
    final trimmed = _displayName.trim().isEmpty ? 'User' : _displayName.trim();
    final short = trimmed.length > 10 ? trimmed.substring(0, 10) : trimmed;
    return '${AppConstants.deviceNamePrefix}$short';
  }

  void _initBleListeners() {
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      _adapterOn = state == BluetoothAdapterState.on;
    });
    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResults);
    _adapterOn =
        FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }

  Future<void> initialize({required String displayName}) async {
    if (!_isBleSupported) return;

    _displayName = displayName;
    await _requestPermissions();
    await _ensureAdapterOn();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
      ].request();
    }
  }

  Future<void> _ensureAdapterOn() async {
    try {
      _adapterOn =
          FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
      if (!_adapterOn && Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
        _adapterOn =
            FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
      }
    } catch (_) {
      _adapterOn = false;
    }
  }

  Future<void> startDiscovery() async {
    if (!_isBleSupported) {
      _connectionController.add(BluetoothConnectionState.error);
      _peersController.add([]);
      return;
    }

    await _ensureAdapterOn();

    if (_scanning) return;
    if (!_adapterOn) {
      _connectionController.add(BluetoothConnectionState.error);
      _peersController.add([]);
      return;
    }

    _scanning = true;
    _discovered.clear();
    _peersController.add([]);
    _connectionController.add(BluetoothConnectionState.scanning);

    try {
      // Scan all devices — filter by BTMsg_ name in results.
      // Both PCs must set Bluetooth device name to BTMsg_YourName in Settings.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _scanning = false;
      _connectionController.add(BluetoothConnectionState.error);
      debugPrint('BLE scan failed: $e');
      return;
    }

    Future.delayed(const Duration(seconds: 15), () {
      if (_scanning) stopDiscovery();
    });
  }

  Future<void> stopDiscovery() async {
    if (!_isBleSupported) return;
    if (!_scanning) return;
    _scanning = false;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _connectionController.add(BluetoothConnectionState.idle);
  }

  void _onScanResults(List<ScanResult> results) {
    for (final result in results) {
      final advName = result.advertisementData.advName;
      final platformName = result.device.platformName;
      final name = advName.isNotEmpty ? advName : platformName;

      if (!name.startsWith(AppConstants.deviceNamePrefix)) continue;

      final deviceId = result.device.remoteId.str;
      final peer = Peer(
        id: deviceId,
        name: name.replaceFirst(AppConstants.deviceNamePrefix, ''),
        deviceId: deviceId,
        rssi: result.rssi,
      );

      _discovered[peer.id] = peer;
      _devices[peer.id] = result.device;
    }

    _peersController.add(_discovered.values.toList());
  }

  Future<void> connect(Peer peer) async {
    if (!_isBleSupported) {
      _connectionController.add(BluetoothConnectionState.error);
      throw UnsupportedError('Bluetooth is not supported on this platform');
    }

    var device = _devices[peer.id];
    device ??= BluetoothDevice.fromId(peer.deviceId);
    _devices[peer.id] = device;

    _connectionController.add(BluetoothConnectionState.connecting);

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
      );
      await _setupCharacteristics(device, peer.id);
      _connectionController.add(BluetoothConnectionState.connected);
    } catch (e) {
      _connectionController.add(BluetoothConnectionState.error);
      rethrow;
    }
  }

  Future<void> disconnect(String peerId) async {
    if (!_isBleSupported) return;
    final device = _devices[peerId];
    await _notifySubs.remove(peerId)?.cancel();
    _writeChars.remove(peerId);
    if (device != null) {
      await device.disconnect();
    }
    _connectionController.add(BluetoothConnectionState.idle);
  }

  Future<void> _setupCharacteristics(
    BluetoothDevice device,
    String peerId,
  ) async {
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == Guid(AppConstants.bleServiceUuid),
      orElse: () =>
          throw StateError('BT Messenger service not found on device'),
    );

    final writeChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(AppConstants.bleTxCharUuid),
    );
    final notifyChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(AppConstants.bleRxCharUuid),
    );

    _writeChars[peerId] = writeChar;

    await _notifySubs.remove(peerId)?.cancel();
    await notifyChar.setNotifyValue(true);
    _notifySubs[peerId] = notifyChar.onValueReceived.listen((data) {
      _handleIncoming(peerId, Uint8List.fromList(data));
    });
  }

  void _handleIncoming(String peerId, Uint8List data) {
    try {
      final json = utf8.decode(data);
      final payload = jsonDecode(json) as Map<String, dynamic>;
      _incomingController.add(
        IncomingPacket(peerId: peerId, payload: payload),
      );
    } catch (_) {
      // Ignore malformed packets
    }
  }

  Future<bool> send(String peerId, Map<String, dynamic> payload) async {
    final characteristic = _writeChars[peerId];
    if (characteristic == null) return false;

    final bytes = utf8.encode(jsonEncode(payload));
    if (bytes.length > AppConstants.maxBlePayload) return false;

    try {
      await characteristic.write(bytes, withoutResponse: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await stopDiscovery();
    for (final sub in _notifySubs.values) {
      await sub.cancel();
    }
    await _scanSub?.cancel();
    await _adapterSub?.cancel();
    await _peersController.close();
    await _incomingController.close();
    await _connectionController.close();
  }
}
