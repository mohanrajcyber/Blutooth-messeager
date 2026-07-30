import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class CodePeerFound {
  CodePeerFound({
    required this.code,
    required this.name,
    required this.address,
    required this.port,
  });

  final String code;
  final String name;
  final InternetAddress address;
  final int port;
}

/// Offline pairing via shared code names over local WiFi / hotspot (no internet).
class CodePairingService {
  String _myCode = '';
  String _myName = 'User';
  String? _connectedPeerCode;
  String? _connectedPeerName;
  String _readBuffer = '';
  String _localIp = '';

  ServerSocket? _server;
  ServerSocket? _discoveryServer;
  RawDatagramSocket? _udp;
  Socket? _socket;
  Timer? _broadcastTimer;
  Timer? _searchProbeTimer;
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;

  String? _sessionKey;
  String? _outgoingSessionKey;
  InternetAddress? _lastAddress;
  int? _lastPort;
  String? _lastPartnerCode;

  Timer? _ipRefreshTimer;

  static const _savedCodeKey = 'bt_device_code';
  String? _searchingForCode;
  Completer<CodePeerFound?>? _searchCompleter;

  final _incomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _pairedController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get incomingStream => _incomingController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<void> get pairedStream => _pairedController.stream;

  String get myCode => _myCode;
  String get localIp => _localIp;
  String? get connectedPeerCode => _connectedPeerCode;
  String? get connectedPeerName => _connectedPeerName;
  bool get isConnected => _socket != null;
  bool get isPaired => _connectedPeerCode != null;
  String? get sessionKey => _sessionKey;

  /// True when on phone hotspot / local WiFi (not mobile-data/VPN).
  bool get isHotspotReady {
    if (_localIp.isEmpty) return false;
    if (_localIp.startsWith('172.')) return false;
    return _localIp.startsWith('192.168.') || _localIp.startsWith('10.');
  }

  String get networkHint {
    if (_localIp.isEmpty) return 'Checking network…';
    if (_localIp.startsWith('172.')) {
      return 'Mobile data/VPN detected ($_localIp). Turn OFF mobile data, turn ON hotspot.';
    }
    if (_localIp.startsWith('192.168.43.') ||
        _localIp.startsWith('192.168.137.')) {
      return 'Hotspot OK — $_localIp';
    }
    return 'Network: $_localIp';
  }

  void setOutgoingSessionKey(String key) => _outgoingSessionKey = key;

  Future<void> start({required String displayName}) async {
    if (_myCode.isNotEmpty) return;

    _myName = displayName.trim().isEmpty ? 'User' : displayName.trim();
    _myCode = await _loadOrCreateCode();
    await _refreshLocalIp();
    await _startServer();
    await _startTcpDiscovery();
    await _startUdp();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _broadcastPresence();
    });
    _ipRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_checkIpChanged());
    });
    _broadcastPresence();
    _statusController.add('Your code: $_myCode');
    _statusController.add(networkHint);
  }

  Future<void> _checkIpChanged() async {
    final prev = _localIp;
    await _refreshLocalIp();
    if (_localIp != prev) {
      _statusController.add(networkHint);
    }
  }

  Future<String> _loadOrCreateCode() async {
    final prefix = (Platform.isAndroid || Platform.isIOS) ? 'MOB' : 'PC';
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_savedCodeKey)?.trim().toUpperCase();
      if (saved != null &&
          saved.startsWith('$prefix-') &&
          saved.length >= 7) {
        return saved;
      }
      final code = _generateCode();
      await prefs.setString(_savedCodeKey, code);
      return code;
    } catch (_) {
      return _generateCode();
    }
  }

  String _generateCode() {
    final prefix = (Platform.isAndroid || Platform.isIOS) ? 'MOB' : 'PC';
    final rand = Random().nextInt(0xFFFF);
    final suffix = rand.toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$prefix-$suffix';
  }

  Future<void> _refreshLocalIp() async {
    _localIp = '';
    final candidates = <String>[];
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!ip.startsWith('127.')) {
            candidates.add(ip);
          }
        }
      }
    } catch (_) {}

    if (candidates.isEmpty) return;

    // Prefer phone-hotspot / local WiFi over VPN or mobile-data interfaces.
    int score(String ip) {
      if (ip.startsWith('192.168.43.')) return 100; // Android hotspot
      if (ip.startsWith('192.168.137.')) return 95; // Windows hotspot client
      if (ip.startsWith('192.168.')) return 80;
      if (ip.startsWith('10.')) return 70;
      if (ip.startsWith('172.')) return 10; // Often VPN / carrier — avoid
      return 20;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    _localIp = candidates.first;
  }

  Future<Set<String>> _allLocalIps() async {
    await _refreshLocalIp();
    final ips = <String>{};
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!ip.startsWith('127.')) ips.add(ip);
        }
      }
    } catch (_) {}
    if (_localIp.isNotEmpty) ips.add(_localIp);
    return ips;
  }

  Future<List<String>> _candidateHostIps() async {
    final ips = <String>{
      '192.168.43.1',
      '192.168.137.1',
      '192.168.0.1',
      '192.168.1.1',
      '192.168.32.1',
    };

    for (final local in await _allLocalIps()) {
      ips.add(local);
      final parts = local.split('.');
      if (parts.length == 4) {
        final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
        ips.add('$prefix.1');
        ips.add('$prefix.255');
        for (var i = 1; i <= 50; i++) {
          ips.add('$prefix.$i');
        }
      }
    }

    return ips.where((ip) => !ip.startsWith('127.')).toList();
  }

  Future<List<InternetAddress>> _udpTargets() async {
    final targets = <InternetAddress>{
      InternetAddress('255.255.255.255'),
    };

    for (final local in await _allLocalIps()) {
      final parts = local.split('.');
      if (parts.length == 4) {
        targets.add(
          InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'),
        );
        targets.add(
          InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.1'),
        );
      }
    }

    for (final ip in await _candidateHostIps()) {
      targets.add(InternetAddress(ip));
    }

    return targets.toList();
  }

  Future<void> _startServer() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_onClient);
  }

  Future<void> _startTcpDiscovery() async {
    try {
      _discoveryServer = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.tcpDiscoveryPort,
        shared: true,
      );
      _discoveryServer!.listen(_onDiscoveryClient);
    } catch (_) {}
  }

  Future<void> _startUdp() async {
    _udp = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.udpDiscoveryPort,
      reuseAddress: true,
      reusePort: !Platform.isWindows,
    );
    _udp!.broadcastEnabled = true;
    _udp!.listen(_onUdp);
  }

  void _broadcastPresence() {
    unawaited(_sendUdpToAll('BTMSG|$_myCode|$_myName|${_server!.port}'));
  }

  Future<void> _sendUdpToAll(String msg) async {
    if (_udp == null || _server == null) return;
    final data = utf8.encode(msg);
    for (final target in await _udpTargets()) {
      try {
        _udp!.send(data, target, AppConstants.udpDiscoveryPort);
      } catch (_) {}
    }
  }

  void _sendPresenceUnicast(InternetAddress address, int port) {
    if (_udp == null || _server == null) return;
    final msg = 'BTMSG|$_myCode|$_myName|${_server!.port}';
    try {
      _udp!.send(utf8.encode(msg), address, port);
    } catch (_) {}
  }

  void _onUdp(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udp == null) return;
    final dg = _udp!.receive();
    if (dg == null) return;

    try {
      final parts = utf8.decode(dg.data).split('|');
      if (parts.isEmpty) return;

      if (parts[0] == 'BTMSG_QUERY' && parts.length >= 2) {
        if (parts[1].toUpperCase() == _myCode.toUpperCase()) {
          _sendPresenceUnicast(dg.address, dg.port);
        }
        return;
      }

      if (parts.length < 4 || parts[0] != 'BTMSG') return;
      if (parts[1].toUpperCase() == _myCode.toUpperCase()) return;

      _maybeCompleteSearch(
        code: parts[1],
        name: parts[2],
        address: dg.address,
        port: int.parse(parts[3]),
      );
    } catch (_) {}
  }

  void _onDiscoveryClient(Socket client) {
    var buffer = '';
    client.listen(
      (data) {
        buffer += utf8.decode(data);
        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          final line = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 1);
          if (line.startsWith('FIND|')) {
            final code = line.substring(5).trim().toUpperCase();
            if (code == _myCode.toUpperCase()) {
              client.add(
                utf8.encode('OK|$_myCode|$_myName|${_server!.port}\n'),
              );
            }
          }
        }
      },
      onDone: () => client.destroy(),
      onError: (_) => client.destroy(),
    );
  }

  void _maybeCompleteSearch({
    required String code,
    required String name,
    required InternetAddress address,
    required int port,
  }) {
    if (_searchingForCode == null ||
        _searchCompleter == null ||
        _searchCompleter!.isCompleted) {
      return;
    }
    if (code.toUpperCase() != _searchingForCode) return;

    _searchCompleter!.complete(
      CodePeerFound(code: code, name: name, address: address, port: port),
    );
  }

  Future<void> _probeForCode(String code) async {
    await _sendUdpToAll('BTMSG_QUERY|$code');
    await _sendUdpToAll('BTMSG|$_myCode|$_myName|${_server!.port}');

    final ips = await _candidateHostIps();
    await Future.wait(
      ips.map((ip) => _tcpProbe(code, ip)),
      eagerError: false,
    );
  }

  Future<void> _tcpProbe(String code, String ip) async {
    if (_searchCompleter?.isCompleted ?? true) return;

    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        AppConstants.tcpDiscoveryPort,
        timeout: const Duration(milliseconds: 600),
      );
      socket.add(utf8.encode('FIND|$code\n'));

      final buffer = StringBuffer();
      await for (final data in socket.timeout(const Duration(seconds: 2))) {
        buffer.write(utf8.decode(data));
        if (!buffer.toString().contains('\n')) continue;

        final line = buffer.toString().split('\n').first.trim();
        final parts = line.split('|');
        if (parts.length >= 4 &&
            parts[0] == 'OK' &&
            parts[1].toUpperCase() == code) {
          _maybeCompleteSearch(
            code: parts[1],
            name: parts[2],
            address: InternetAddress(ip),
            port: int.parse(parts[3]),
          );
          break;
        }
      }
    } catch (_) {
    } finally {
      await socket?.close();
    }
  }

  Future<bool> connectToCode(String partnerCode) async {
    if (_myCode.isEmpty || _server == null || _udp == null) {
      _statusController.add('Pairing not ready — wait a moment and try again');
      return false;
    }

    final code = partnerCode.trim().toUpperCase();
    if (code.isEmpty) return false;
    if (code == _myCode.toUpperCase()) {
      _statusController.add('Enter partner code, not your own');
      return false;
    }

    _searchingForCode = code;
    _searchCompleter = Completer<CodePeerFound?>();
    _statusController.add(
      _localIp.isEmpty
          ? 'Searching for $code…'
          : 'Searching for $code on $_localIp…',
    );

    _searchProbeTimer?.cancel();
    _searchProbeTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_probeForCode(code)),
    );
    unawaited(_probeForCode(code));

    final found = await _searchCompleter!.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () => null,
    );

    _searchProbeTimer?.cancel();
    _searchProbeTimer = null;
    _searchingForCode = null;
    _searchCompleter = null;

    if (found == null) {
      _statusController.add(
        'Code $code not found on $_localIp. '
        'Phone hotspot ON → PC connect same WiFi → mobile data OFF on phone.',
      );
      return false;
    }

    try {
      _socket = await Socket.connect(
        found.address,
        found.port,
        timeout: const Duration(seconds: 8),
      );
      _readBuffer = '';
      _connectedPeerCode = found.code;
      _connectedPeerName = found.name;
      _lastAddress = found.address;
      _lastPort = found.port;
      _lastPartnerCode = found.code;
      _socket!.listen(
        _onSocketData,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
      _startKeepalive();
      _statusController.add('Connected to ${found.name}');

      await _sendHello();
      _pairedController.add(null);
      return true;
    } catch (e) {
      _statusController.add('Connection failed — check Windows Firewall');
      return false;
    }
  }

  Future<void> _sendHello() async {
    await send({
      'type': 'hello',
      'code': _myCode,
      'name': _myName,
      if (_outgoingSessionKey != null) 'session_key': _outgoingSessionKey,
    });
  }

  void _scheduleReconnect() {
    if (_lastAddress == null || _lastPort == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (_socket != null) return;
      try {
        _socket = await Socket.connect(
          _lastAddress!,
          _lastPort!,
          timeout: const Duration(seconds: 8),
        );
        _readBuffer = '';
        _socket!.listen(
          _onSocketData,
          onDone: _scheduleReconnect,
          onError: (_) => _scheduleReconnect(),
        );
        _startKeepalive();
        await _sendHello();
        _statusController.add('Reconnected');
      } catch (_) {}
    });
  }

  void _onClient(Socket client) {
    _socket?.destroy();
    _socket = client;
    _readBuffer = '';
    _socket!.listen(_onSocketData);
    _startKeepalive();
    _statusController.add('Partner connected');
    unawaited(_sendHello());
  }

  void _onSocketData(List<int> data) {
    _readBuffer += utf8.decode(data);
    while (_readBuffer.contains('\n')) {
      final idx = _readBuffer.indexOf('\n');
      final line = _readBuffer.substring(0, idx).trim();
      _readBuffer = _readBuffer.substring(idx + 1);
      if (line.isEmpty) continue;
      _handleLine(line);
    }
  }

  void _startKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_socket != null) {
        unawaited(send({'type': 'ping'}));
      }
    });
  }

  void _handleLine(String line) {
    try {
      final payload = jsonDecode(line) as Map<String, dynamic>;
      final type = payload['type'] as String?;
      if (type == 'ping') {
        unawaited(send({'type': 'pong'}));
        return;
      }
      if (type == 'pong') return;
      if (type == 'hello') {
        _connectedPeerCode = payload['code'] as String?;
        _connectedPeerName = payload['name'] as String?;
        _sessionKey = payload['session_key'] as String? ?? _sessionKey;
        _statusController.add('Paired with $_connectedPeerName');
        _pairedController.add(null);
      }
      _incomingController.add(payload);
    } catch (_) {}
  }

  Future<bool> send(Map<String, dynamic> payload) async {
    if (_socket == null) return false;
    try {
      _socket!.add(utf8.encode('${jsonEncode(payload)}\n'));
      return true;
    } catch (_) {
      return false;
    }
  }

  String get localPeerId {
    final partner = _connectedPeerCode;
    if (partner != null) {
      return '${AppConstants.localPeerPrefix}$partner';
    }
    return '${AppConstants.localPeerPrefix}$_myCode';
  }

  Future<void> dispose() async {
    _broadcastTimer?.cancel();
    _ipRefreshTimer?.cancel();
    _searchProbeTimer?.cancel();
    _keepaliveTimer?.cancel();
    _reconnectTimer?.cancel();
    await _socket?.close();
    _udp?.close();
    await _discoveryServer?.close();
    await _server?.close();
    await _incomingController.close();
    await _statusController.close();
    await _pairedController.close();
  }
}
