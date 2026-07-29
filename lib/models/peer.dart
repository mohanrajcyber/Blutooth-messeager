class Peer {
  const Peer({
    required this.id,
    required this.name,
    required this.deviceId,
    this.rssi,
    this.isConnected = false,
  });

  final String id;
  final String name;
  final String deviceId;
  final int? rssi;
  final bool isConnected;

  Peer copyWith({
    String? id,
    String? name,
    String? deviceId,
    int? rssi,
    bool? isConnected,
  }) {
    return Peer(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
