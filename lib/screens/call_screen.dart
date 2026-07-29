import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.isVideo = false,
  });

  final String peerId;
  final String peerName;
  final bool isVideo;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  String _status = 'Calling…';

  @override
  void initState() {
    super.initState();
    _invite();
  }

  Future<void> _invite() async {
    final code = ref.read(codePairingServiceProvider);
    await code.send({
      'type': 'call_invite',
      'video': widget.isVideo,
      'from': code.myCode,
    });
    setState(() => _status = 'Waiting for answer…');
  }

  Future<void> _end() async {
    await ref.read(codePairingServiceProvider).send({'type': 'call_end'});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              child: Text(widget.peerName[0].toUpperCase()),
            ),
            const SizedBox(height: 16),
            Text(
              widget.peerName,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              widget.isVideo ? 'Video call (local network)' : 'Voice call',
              style: const TextStyle(color: Colors.white54),
            ),
            const Spacer(),
            FloatingActionButton.large(
              backgroundColor: Colors.red,
              onPressed: _end,
              child: const Icon(Icons.call_end),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
