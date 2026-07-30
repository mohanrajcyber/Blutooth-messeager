import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_constants.dart';
import '../../models/peer.dart';
import 'ble_advertiser.dart';

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

  final _advertiser = BleAdvertiser();
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
  Timer? _scanRestartTimer;

  Stream<List<Peer>> get peersStream => _peersController.stream;
  Stream<IncomingPacket> get incomingStream => _incomingController.stream;
  Stream<BluetoothConnectionState> get connectionStream =>
      _connectionController.stream;

  bool get isAdapterOn => _adapterOn;
  bool get isBleSupported => _isBleSupported;
  bool get isAdvertising => _advertiser.isRunning;
  String? get advertiseError => _advertiser.lastError;

  bool get isScanning => _scanning;
  int get discoveredCount => _discovered.length;

  String get advertiseName {
    final trimmed = _displayName.trim().isEmpty ? 'User' : _displayName.trim();
    final short = trimmed.length > 8 ? trimmed.substring(0, 8) : trimmed;
    return '${AppConstants.deviceNamePrefix}$short';
  }

  String _shortId(String deviceId) {
    if (deviceId.length <= 8) return deviceId;
    return deviceId.substring(deviceId.length - 8);
  }

  String _peerLabel({
    required String deviceId,
    required String name,
    required bool isMessenger,
  }) {
    if (name.isNotEmpty) {
      return isMessenger ? _nameWithoutPrefix(name) : name;
    }
    return 'Unknown device · ${_shortId(deviceId)}';
  }

  bool _matchesPrefix(String name) {
    return name.startsWith(AppConstants.deviceNamePrefix) ||
        name.startsWith(AppConstants.legacyDeviceNamePrefix);
  }

  String _nameWithoutPrefix(String name) {
    if (name.startsWith(AppConstants.deviceNamePrefix)) {
      return name.replaceFirst(AppConstants.deviceNamePrefix, '');
    }
    if (name.startsWith(AppConstants.legacyDeviceNamePrefix)) {
      return name.replaceFirst(AppConstants.legacyDeviceNamePrefix, '');
    }
    return name;
  }

  bool _hasOurService(ScanResult result) {
    final target = AppConstants.bleServiceUuid.toLowerCase();
    return result.advertisementData.serviceUuids
        .any((uuid) => uuid.toString().toLowerCase() == target);
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
    await _advertiser.start(displayName);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
        Permission.location,
        Permission.notification,
      ].request();
    } else if (Platform.isIOS || Platform.isMacOS) {
      await [
        Permission.bluetooth,
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
    await _startDiscovery(clearList: true);
  }

  /// Force a fresh scan (refresh button).
  Future<void> rescan() async {
    _scanRestartTimer?.cancel();
    _scanRestartTimer = null;
    if (_scanning) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      _scanning = false;
    }
    await _startDiscovery(clearList: true);
  }

  Future<void> _startDiscovery({required bool clearList}) async {
    if (!_isBleSupported) {
      _connectionController.add(BluetoothConnectionState.error);
      _peersController.add([]);
      return;
    }

    await _ensureAdapterOn();
    if (!_advertiser.isRunning) {
      await _advertiser.start(_displayName);
    }

    if (!_adapterOn) {
      _connectionController.add(BluetoothConnectionState.error);
      _peersController.add([]);
      return;
    }

    if (clearList) {
      _discovered.clear();
      _peersController.add([]);
    }

    _scanning = true;
    _connectionController.add(BluetoothConnectionState.scanning);

    await _loadKnownDevices();

    try {
      await _runScanPass();
      _scheduleScanRestarts();
    } catch (e) {
      _scanning = false;
      _scanRestartTimer?.cancel();
      _connectionController.add(BluetoothConnectionState.error);
      debugPrint('BLE scan failed: $e');
    }
  }

  Future<void> _runScanPass() async {
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 0),
      continuousUpdates: true,
      androidScanMode: AndroidScanMode.lowLatency,
      androidUsesFineLocation: true,
      androidLegacy: Platform.isAndroid,
    );
  }

  void _scheduleScanRestarts() {
    _scanRestartTimer?.cancel();
    _scanRestartTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_scanning) return;
      try {
        await _runScanPass();
      } catch (e) {
        debugPrint('BLE scan restart: $e');
      }
    });
  }

  Future<void> retryAdvertising() async {
    await _advertiser.stop();
    await _advertiser.start(_displayName);
  }

  Future<void> _loadKnownDevices() async {
    try {
      for (final services in [
        [Guid('1800')],
        [Guid(AppConstants.bleServiceUuid)],
      ]) {
        final devices = await FlutterBluePlus.systemDevices(services);
        for (final device in devices) {
          _addDevice(device, rssi: null);
        }
      }

      if (Platform.isAndroid) {
        for (final device in await FlutterBluePlus.bondedDevices) {
          _addDevice(device, rssi: null);
        }
      }

      _peersController.add(_discovered.values.toList());
    } catch (e) {
      debugPrint('Load known BT devices: $e');
    }
  }

  void _addDevice(BluetoothDevice device, {int? rssi}) {
    final advName = device.advName;
    final platformName = device.platformName;
    final name = advName.isNotEmpty ? advName : platformName;

    final isMessenger = _matchesPrefix(name);
    final deviceId = device.remoteId.str;

    final peer = Peer(
      id: deviceId,
      name: _peerLabel(
        deviceId: deviceId,
        name: name,
        isMessenger: isMessenger,
      ),
      deviceId: deviceId,
      rssi: rssi,
      isMessenger: isMessenger,
    );

    _discovered[peer.id] = peer;
    _devices[peer.id] = device;
  }

  Future<void> stopDiscovery() async {
    if (!_isBleSupported) return;
    if (!_scanning) return;
    _scanning = false;
    _scanRestartTimer?.cancel();
    _scanRestartTimer = null;
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

      final isMessenger = _matchesPrefix(name) || _hasOurService(result);
      final deviceId = result.device.remoteId.str;

      final peer = Peer(
        id: deviceId,
        name: _peerLabel(
          deviceId: deviceId,
          name: name,
          isMessenger: isMessenger,
        ),
        deviceId: deviceId,
        rssi: result.rssi,
        isMessenger: isMessenger,
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
        timeout: const Duration(seconds: 20),
        autoConnect: true,
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
    _scanRestartTimer?.cancel();
    await stopDiscovery();
    await _advertiser.stop();
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
