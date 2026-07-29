import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  final Message message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = chatTheme(context);
    final isOutgoing = message.isOutgoing;
    final time = DateFormat('HH:mm').format(message.createdAt);
    final bubbleColor =
        isOutgoing ? theme.bubbleSent : theme.bubbleReceived;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: message.status == MessageStatus.failed ? onRetry : null,
          child: Container(
            margin: EdgeInsets.only(
              left: isOutgoing ? 56 : 8,
              right: isOutgoing ? 8 : 56,
              top: 3,
              bottom: 3,
            ),
            padding: message.type == MessageType.image
                ? const EdgeInsets.all(4)
                : const EdgeInsets.fromLTRB(12, 8, 8, 6),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.type == MessageType.image)
                  _ImageBubble(path: message.body)
                else
                  Text(
                    message.body,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.35,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.subtitle,
                      ),
                    ),
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

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.broken_image_outlined, size: 48),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        width: 220,
        fit: BoxFit.cover,
      ),
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

    IconData icon;
    switch (status) {
      case MessageStatus.pending:
        icon = Icons.access_time;
      case MessageStatus.failed:
        icon = Icons.error_outline;
      case MessageStatus.sent:
        icon = Icons.done;
      case MessageStatus.delivered:
      case MessageStatus.read:
        icon = Icons.done_all;
    }

    return Icon(icon, size: 16, color: color);
  }
}
