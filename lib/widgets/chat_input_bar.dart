import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
  });

  final ValueChanged<String> onSend;
  final bool enabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.divider,
      padding: EdgeInsets.fromLTRB(
        8,
        6,
        8,
        6 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Message',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: widget.enabled ? AppColors.accent : Colors.grey,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.enabled ? _submit : null,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
