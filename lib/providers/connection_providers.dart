import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../services/bluetooth/bluetooth_service.dart';
import 'app_providers.dart';

class ActiveSession {
  const ActiveSession({
    required this.peerId,
    required this.peerName,
    required this.viaCode,
  });

  final String peerId;
  final String peerName;
  final bool viaCode;
}

final activeSessionProvider = StateProvider<ActiveSession?>((ref) => null);

bool isLocalPeerId(String peerId) =>
    peerId.startsWith(AppConstants.localPeerPrefix);

final peerOnlineProvider = Provider.family<bool, String>((ref, peerId) {
  if (isLocalPeerId(peerId)) {
    final code = ref.watch(codePairingServiceProvider);
    return code.isConnected &&
        (code.localPeerId == peerId || code.connectedPeerCode != null);
  }

  final connection = ref.watch(connectionStateProvider);
  return connection.maybeWhen(
    data: (state) => state == BluetoothConnectionState.connected,
    orElse: () => false,
  );
});
