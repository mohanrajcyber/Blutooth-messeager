import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Socket? _socket;
  Timer? _broadcastTimer;

  String? _searchingForCode;
  Completer<CodePeerFound?>? _searchCompleter;

  final _incomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _pairedController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get incomingStream => _incomingController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<void> get pairedStream => _pairedController.stream;

  String get myCode => _myCode;
  String? get connectedPeerCode => _connectedPeerCode;
  String? get connectedPeerName => _connectedPeerName;
  bool get isConnected => _socket != null;
  bool get isPaired => _connectedPeerCode != null;

  Future<void> start({required String displayName}) async {
    if (_myCode.isNotEmpty) return;

    _myName = displayName.trim().isEmpty ? 'User' : displayName.trim();
    _myCode = _generateCode();
    await _startServer();
    await _startUdp();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _broadcastPresence();
    });
    _broadcastPresence();
    _statusController.add('Your code: $_myCode');
  }

  String _generateCode() {
    final prefix = (Platform.isAndroid || Platform.isIOS) ? 'MOB' : 'PC';
    final rand = Random().nextInt(0xFFFF);
    final suffix = rand.toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$prefix-$suffix';
  }

  Future<void> _startServer() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_onClient);
  }

  Future<void> _startUdp() async {
    _udp = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.udpDiscoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _udp!.broadcastEnabled = true;
    _udp!.listen(_onUdp);
  }

  void _broadcastPresence() {
    if (_udp == null || _server == null) return;
    final msg = 'BTMSG|$_myCode|$_myName|${_server!.port}';
    _udp!.send(
      utf8.encode(msg),
      InternetAddress('255.255.255.255'),
      AppConstants.udpDiscoveryPort,
    );
  }

  void _onUdp(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udp == null) return;
    final dg = _udp!.receive();
    if (dg == null) return;

    try {
      final parts = utf8.decode(dg.data).split('|');
      if (parts.length < 4 || parts[0] != 'BTMSG') return;
      if (parts[1] == _myCode) return;

      if (_searchingForCode != null &&
          parts[1].toUpperCase() == _searchingForCode &&
          _searchCompleter != null &&
          !_searchCompleter!.isCompleted) {
        _searchCompleter!.complete(
          CodePeerFound(
            code: parts[1],
            name: parts[2],
            address: dg.address,
            port: int.parse(parts[3]),
          ),
        );
      }
    } catch (_) {}
  }

  Future<bool> connectToCode(String partnerCode) async {
    final code = partnerCode.trim().toUpperCase();
    if (code.isEmpty) return false;
    if (code == _myCode) {
      _statusController.add('Enter partner code, not your own');
      return false;
    }

    _searchingForCode = code;
    _searchCompleter = Completer<CodePeerFound?>();
    _statusController.add('Searching for $code…');
    _broadcastPresence();

    final found = await _searchCompleter!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => null,
    );

    _searchingForCode = null;
    _searchCompleter = null;

    if (found == null) {
      _statusController.add(
        'Code $code not found. Use same WiFi or phone hotspot.',
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
      _socket!.listen(_onSocketData);
      _statusController.add('Connected to ${found.name}');

      await _sendHello();
      _pairedController.add(null);
      return true;
    } catch (e) {
      _statusController.add('Connection failed');
      return false;
    }
  }

  Future<void> _sendHello() async {
    await send({
      'type': 'hello',
      'code': _myCode,
      'name': _myName,
    });
  }

  void _onClient(Socket client) {
    _socket?.destroy();
    _socket = client;
    _readBuffer = '';
    _socket!.listen(_onSocketData);
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

  void _handleLine(String line) {
    try {
      final payload = jsonDecode(line) as Map<String, dynamic>;
      if (payload['type'] == 'hello') {
        _connectedPeerCode = payload['code'] as String?;
        _connectedPeerName = payload['name'] as String?;
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
    await _socket?.close();
    _udp?.close();
    await _server?.close();
    await _incomingController.close();
    await _statusController.close();
    await _pairedController.close();
  }
}
