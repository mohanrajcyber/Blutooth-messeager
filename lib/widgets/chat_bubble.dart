import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/message.dart';
import '../screens/image_viewer_screen.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onLongPress,
    this.replyPreview,
  });

  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;
  final String? replyPreview;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return const SizedBox.shrink();

    final theme = chatTheme(context);
    final isOutgoing = message.isOutgoing;
    final time = DateFormat('HH:mm').format(message.createdAt);
    final bubbleColor =
        isOutgoing ? theme.bubbleSent : theme.bubbleReceived;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: message.status == MessageStatus.failed ? onRetry : null,
          onLongPress: onLongPress,
          child: Container(
            margin: EdgeInsets.only(
              left: isOutgoing ? 56 : 8,
              right: isOutgoing ? 8 : 56,
              top: 3,
              bottom: 3,
            ),
            padding: message.type == MessageType.text
                ? const EdgeInsets.fromLTRB(12, 8, 8, 6)
                : const EdgeInsets.all(4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isOutgoing ? 12 : 2),
                bottomRight: Radius.circular(isOutgoing ? 2 : 12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyPreview != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      replyPreview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: theme.subtitle),
                    ),
                  ),
                if (message.forwardedFrom != null)
                  Text(
                    'Forwarded',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: theme.subtitle,
                    ),
                  ),
                _Body(message: message),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.status == MessageStatus.failed) ...[
                      Text(
                        'Tap to retry',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(time, style: TextStyle(fontSize: 11, color: theme.subtitle)),
                    if (isOutgoing) ...[
                      const SizedBox(width: 4),
                      _StatusTicks(status: message.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _ImageBody(path: message.body);
      case MessageType.voice:
        return _VoiceBody(path: message.body);
      case MessageType.video:
        return const ListTile(
          dense: true,
          leading: Icon(Icons.videocam),
          title: Text('Video message'),
        );
      case MessageType.document:
        return ListTile(
          dense: true,
          leading: const Icon(Icons.insert_drive_file),
          title: Text(message.body.split(RegExp(r'[/\\]')).last),
        );
      default:
        return Text(
          message.body,
          style: TextStyle(
            fontSize: 15.5,
            height: 1.35,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        );
    }
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Icon(Icons.broken_image_outlined, size: 48);
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ImageViewerScreen(path: path)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(file, width: 220, fit: BoxFit.cover),
      ),
    );
  }
}

class _VoiceBody extends StatelessWidget {
  const _VoiceBody({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic, size: 20),
        const SizedBox(width: 8),
        Text(path.split(RegExp(r'[/\\]')).last),
      ],
    );
  }
}

class _StatusTicks extends StatelessWidget {
  const _StatusTicks({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == MessageStatus.read ||
            status == MessageStatus.delivered
        ? AppColors.tickBlue
        : AppColors.subtitle;

    final icon = switch (status) {
      MessageStatus.pending => Icons.access_time,
      MessageStatus.failed => Icons.error_outline,
      MessageStatus.sent => Icons.done,
      MessageStatus.delivered || MessageStatus.read => Icons.done_all,
    };

    return Icon(icon, size: 16, color: color);
  }
}
