import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ble_peripheral_plus/ble_peripheral_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// Starts BLE GATT server + advertising so other devices can discover us.
class BleAdvertiser {
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start(String displayName) async {
    if (_running) return;
    if (!(Platform.isAndroid || Platform.isWindows || Platform.isMacOS)) {
      return;
    }

    try {
      await BlePeripheral.initialize();
      if (!await BlePeripheral.isSupported()) return;

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
      debugPrint('BLE advertising as $localName');
    } catch (e) {
      debugPrint('BLE advertise failed: $e');
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
