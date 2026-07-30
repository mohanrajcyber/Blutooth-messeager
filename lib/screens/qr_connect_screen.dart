import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/pairing_navigation.dart';
import '../providers/app_providers.dart';
import '../providers/settings_providers.dart';
import '../services/security/encryption_service.dart';

class QrConnectScreen extends ConsumerStatefulWidget {
  const QrConnectScreen({super.key});

  @override
  ConsumerState<QrConnectScreen> createState() => _QrConnectScreenState();
}

class _QrConnectScreenState extends ConsumerState<QrConnectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final name = ref.read(displayNameProvider);
      await PairingNavigation.ensureStarted(ref, name);
      await ref.read(codePairingServiceProvider).regenerateCode();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(codePairingServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('QR Connect')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Scan this QR on partner device',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (code.myCode.isNotEmpty)
              QrImageView(
                data: code.myCode,
                size: 220,
                backgroundColor: Colors.white,
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              code.myCode.isEmpty ? 'Starting…' : code.myCode,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            if (code.localIp.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                code.networkHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: code.isHotspotReady ? Colors.green : Colors.orange,
                  fontSize: 13,
                ),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: code.myCode.isEmpty
                  ? null
                  : () async {
                      await code.regenerateCode();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('New code: ${code.myCode}')),
                        );
                      }
                      setState(() {});
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('New code'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: code.myCode.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QrScanScreen()),
                      );
                    },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan partner QR'),
            ),
          ],
        ),
      ),
    );
  }
}

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  bool _done = false;

  Future<void> _onCode(String raw) async {
    if (_done) return;
    _done = true;

    final name = ref.read(displayNameProvider);
    await PairingNavigation.ensureStarted(ref, name);

    final encryption = ref.read(encryptionServiceProvider);
    ref
        .read(codePairingServiceProvider)
        .setOutgoingSessionKey(encryption.generateSessionKey());

    final ok = await ref.read(codePairingServiceProvider).connectToCode(raw);
    if (!mounted) return;

    if (ok) {
      await PairingNavigation.openChatIfPaired(context, ref, replace: true);
    } else {
      _done = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(codePairingServiceProvider).isHotspotReady
                ? 'Could not connect — keep partner on Connect/QR screen'
                : 'Mobile data OFF + phone hotspot ON, then retry',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: MobileScanner(
        onDetect: (capture) async {
          final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
          if (raw == null || raw.isEmpty) return;
          await _onCode(raw.toUpperCase());
        },
      ),
    );
  }
}

extension _FirstBarcode on List<Barcode> {
  Barcode? get firstOrNull => isEmpty ? null : first;
}
