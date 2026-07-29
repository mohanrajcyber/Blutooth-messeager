class Peer {
  const Peer({
    required this.id,
    required this.name,
    required this.deviceId,
    this.rssi,
    this.isConnected = false,
    this.isMessenger = false,
    this.viaCode = false,
  });

  final String id;
  final String name;
  final String deviceId;
  final int? rssi;
  final bool isConnected;
  final bool isMessenger;
  final bool viaCode;

  Peer copyWith({
    String? id,
    String? name,
    String? deviceId,
    int? rssi,
    bool? isConnected,
    bool? isMessenger,
    bool? viaCode,
  }) {
    return Peer(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      isMessenger: isMessenger ?? this.isMessenger,
      viaCode: viaCode ?? this.viaCode,
    );
  }
}
