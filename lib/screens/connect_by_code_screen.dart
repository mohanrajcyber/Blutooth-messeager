import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/settings_providers.dart';
import 'chat_screen.dart';

class ConnectByCodeScreen extends ConsumerStatefulWidget {
  const ConnectByCodeScreen({super.key});

  @override
  ConsumerState<ConnectByCodeScreen> createState() =>
      _ConnectByCodeScreenState();
}

class _ConnectByCodeScreenState extends ConsumerState<ConnectByCodeScreen> {
  final _partnerCodeController = TextEditingController();
  String _status = 'Starting…';
  StreamSubscription<void>? _pairedSub;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final name = ref.read(displayNameProvider);
    final code = ref.read(codePairingServiceProvider);
    await code.start(displayName: name);
    code.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _pairedSub = code.pairedStream.listen((_) => _openChatIfPaired());
    if (mounted) setState(() => _status = 'Your code: ${code.myCode}');
  }

  Future<void> _openChatIfPaired() async {
    if (_navigating || !mounted) return;
    final code = ref.read(codePairingServiceProvider);
    if (!code.isPaired) return;

    _navigating = true;
    final peerId = code.localPeerId;
    final peerName = code.connectedPeerName ?? code.connectedPeerCode ?? 'Partner';

    ref.read(activeSessionProvider.notifier).state = ActiveSession(
      peerId: peerId,
      peerName: peerName,
      viaCode: true,
    );

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: peerId,
          peerName: peerName,
          viaCode: true,
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final partner = _partnerCodeController.text.trim().toUpperCase();
    if (partner.isEmpty) return;

    final code = ref.read(codePairingServiceProvider);
    final ok = await code.connectToCode(partner);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not find $partner. Same WiFi or phone hotspot required.',
          ),
        ),
      );
      return;
    }

    await _openChatIfPaired();
  }

  @override
  void dispose() {
    _pairedSub?.cancel();
    _partnerCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(codePairingServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect by code')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Your code name',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      code.myCode.isEmpty ? '…' : code.myCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: code.myCode.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: code.myCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')),
                              );
                            },
                      icon: const Icon(Icons.copy, color: Colors.white),
                      label: const Text(
                        'Copy code',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter partner code',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _partnerCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. MOB-A1B2 or PC-X7K2',
                prefixIcon: Icon(Icons.link),
              ),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.link),
              label: const Text('Connect & pair'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            if (code.localIp.isNotEmpty)
              Text(
                'Network: ${code.localIp}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.subtitle,
                  fontSize: 13,
                ),
              ),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subtitle),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Phone-ல Connect by code screen open வை\n'
              '2. Phone hotspot ON → PC join (Nothing Phone WiFi)\n'
              '3. PC code phone-ல enter, phone code PC-ல enter\n'
              '4. Windows Firewall block ஆனா allow பண்ணுங்க',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtitle, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
