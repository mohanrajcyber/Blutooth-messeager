import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isOutgoing;
    final time = DateFormat('HH:mm').format(message.createdAt);

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isOutgoing ? 64 : 8,
          right: isOutgoing ? 8 : 64,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
        decoration: BoxDecoration(
          color: isOutgoing ? AppColors.sentBubble : AppColors.receivedBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(isOutgoing ? 8 : 0),
            bottomRight: Radius.circular(isOutgoing ? 0 : 8),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: const TextStyle(fontSize: 15.5, height: 1.3),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.subtitle,
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
    );
  }
}

class _StatusTicks extends StatelessWidget {
  const _StatusTicks({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == MessageStatus.read || status == MessageStatus.delivered
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
