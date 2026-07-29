import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/app_providers.dart';
import '../services/security/encryption_service.dart';

class QrConnectScreen extends ConsumerWidget {
  const QrConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              ),
            const SizedBox(height: 16),
            Text(
              code.myCode,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: MobileScanner(
        onDetect: (capture) async {
          if (_done) return;
          final raw = capture.barcodes.firstOrNull?.rawValue;
          if (raw == null || raw.isEmpty) return;
          _done = true;

          final encryption = ref.read(encryptionServiceProvider);
          ref
              .read(codePairingServiceProvider)
              .setOutgoingSessionKey(encryption.generateSessionKey());

          final ok =
              await ref.read(codePairingServiceProvider).connectToCode(raw);
          if (!mounted) return;
          if (ok) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          } else {
            _done = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not connect')),
            );
          }
        },
      ),
    );
  }
}

extension _FirstBarcode on List<Barcode> {
  Barcode? get firstOrNull => isEmpty ? null : first;
}
