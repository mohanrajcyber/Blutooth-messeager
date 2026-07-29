import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../core/constants/app_constants.dart';

/// Group chat hub — host relays messages to up to 5 members on same hotspot.
class GroupChatService {
  String _groupCode = '';
  String _groupName = 'Group';
  final _members = <Socket>{};
  ServerSocket? _server;
  Socket? _hostSocket;
  String _readBuffer = '';

  final _incomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingStream => _incomingController.stream;
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  String get groupCode => _groupCode;
  bool get isHost => _server != null;
  bool get isConnected => _server != null || _hostSocket != null;
  int get memberCount => _members.length + (isHost ? 1 : 0);

  Future<String> createGroup({required String name}) async {
    _groupName = name;
    _groupCode = _generateCode();
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 45681);
    _server!.listen(_onMember);
    return _groupCode;
  }

  String _generateCode() {
    final rand = Random().nextInt(0xFFFF);
    return 'GRP-${rand.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  void _onMember(Socket client) {
    _members.add(client);
    client.listen(
      (data) => _relay(client, data),
      onDone: () => _members.remove(client),
      onError: (_) => _members.remove(client),
    );
    _eventController.add({'type': 'member_joined'});
  }

  void _relay(Socket from, List<int> data) {
    for (final m in _members) {
      if (m != from) {
        try {
          m.add(data);
        } catch (_) {}
      }
    }
    _handleData(data);
  }

  Future<bool> joinGroup(String code, String hostIp) async {
    try {
      _hostSocket = await Socket.connect(
        hostIp,
        45681,
        timeout: const Duration(seconds: 8),
      );
      _groupCode = code.toUpperCase();
      _hostSocket!.listen(_handleData);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleData(List<int> data) {
    _readBuffer += utf8.decode(data);
    while (_readBuffer.contains('\n')) {
      final idx = _readBuffer.indexOf('\n');
      final line = _readBuffer.substring(0, idx).trim();
      _readBuffer = _readBuffer.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final payload = jsonDecode(line) as Map<String, dynamic>;
        _incomingController.add(payload);
      } catch (_) {}
    }
  }

  Future<bool> broadcast(Map<String, dynamic> payload) async {
    final line = utf8.encode('${jsonEncode(payload)}\n');
    if (isHost) {
      for (final m in _members) {
        try {
          m.add(line);
        } catch (_) {}
      }
      return true;
    }
    if (_hostSocket != null) {
      try {
        _hostSocket!.add(line);
        return true;
      } catch (_) {}
    }
    return false;
  }

  String get groupPeerId => '${AppConstants.localPeerPrefix}group:$_groupCode';

  Future<void> dispose() async {
    for (final m in _members) {
      await m.close();
    }
    await _hostSocket?.close();
    await _server?.close();
    await _incomingController.close();
    await _eventController.close();
  }
}
