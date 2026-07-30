import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ble_peripheral_plus/ble_peripheral_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// Starts BLE GATT server + advertising so other devices can discover us.
class BleAdvertiser {
  bool _running = false;
  String? _lastError;

  bool get isRunning => _running;
  String? get lastError => _lastError;

  Future<void> start(String displayName) async {
    if (_running) return;
    if (!(Platform.isAndroid || Platform.isWindows || Platform.isMacOS)) {
      _lastError = 'BLE advertising not supported on this platform';
      return;
    }

    _lastError = null;
    for (var attempt = 0; attempt < 3 && !_running; attempt++) {
      try {
        await BlePeripheral.initialize();
        if (!await BlePeripheral.isSupported()) {
          _lastError = 'BLE peripheral mode not supported';
          return;
        }

        BlePeripheral.setWriteRequestCallback(
          (deviceId, characteristicId, offset, value) {
            return WriteRequestResult(status: 0);
          },
        );

        await BlePeripheral.clearServices();
        await BlePeripheral.addService(
          BleService(
            uuid: AppConstants.bleServiceUuid,
            primary: true,
            characteristics: [
              BleCharacteristic(
                uuid: AppConstants.bleTxCharUuid,
                properties: [CharacteristicProperties.write.index],
                permissions: [AttributePermissions.writeable.index],
                descriptors: null,
                value: Uint8List(0),
              ),
              BleCharacteristic(
                uuid: AppConstants.bleRxCharUuid,
                properties: [CharacteristicProperties.notify.index],
                permissions: [AttributePermissions.readable.index],
                descriptors: null,
                value: Uint8List(0),
              ),
            ],
          ),
        );

        final localName = _localName(displayName);
        await BlePeripheral.startAdvertising(
          services: [AppConstants.bleServiceUuid],
          localName: localName,
          requireBonding: false,
        );
        _running = true;
        _lastError = null;
        debugPrint('BLE advertising as $localName');
        return;
      } catch (e) {
        _lastError = e.toString();
        debugPrint('BLE advertise failed (attempt ${attempt + 1}): $e');
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    try {
      await BlePeripheral.stopAdvertising();
    } catch (_) {}
    _running = false;
  }

  String _localName(String displayName) {
    final trimmed = displayName.trim().isEmpty ? 'User' : displayName.trim();
    final short = trimmed.length > 8 ? trimmed.substring(0, 8) : trimmed;
    return '${AppConstants.deviceNamePrefix}$short';
  }
}
