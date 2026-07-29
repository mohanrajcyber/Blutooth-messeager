import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Session E2E encryption for payloads over local transport.
class EncryptionService {
  Key? _key;
  final _iv = IV.fromLength(16);

  bool get isReady => _key != null;

  void setSessionKey(String base64Key) {
    _key = Key.fromBase64(base64Key);
  }

  String generateSessionKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    final key = base64Encode(bytes);
    setSessionKey(key);
    return key;
  }

  Map<String, dynamic> encryptPayload(Map<String, dynamic> payload) {
    if (_key == null) return payload;
    final encrypter = Encrypter(AES(_key!));
    final plain = jsonEncode(payload);
    final encrypted = encrypter.encrypt(plain, iv: _iv);
    return {
      'type': 'encrypted',
      'data': encrypted.base64,
      'iv': _iv.base64,
    };
  }

  Map<String, dynamic>? decryptPayload(Map<String, dynamic> payload) {
    if (payload['type'] != 'encrypted') return payload;
    if (_key == null) return null;
    try {
      final encrypter = Encrypter(AES(_key!));
      final iv = IV.fromBase64(payload['iv'] as String);
      final decrypted = encrypter.decrypt64(payload['data'] as String, iv: iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}
