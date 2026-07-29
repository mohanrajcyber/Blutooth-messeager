import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onImagePicked,
    required this.onVideoPicked,
    required this.onDocumentPicked,
    required this.onVoiceStart,
    required this.onVoiceStop,
    this.onTyping,
    this.enabled = true,
  });

  final ValueChanged<String> onSend;
  final Future<void> Function(ImageSource source) onImagePicked;
  final VoidCallback onVideoPicked;
  final VoidCallback onDocumentPicked;
  final VoidCallback onVoiceStart;
  final Future<void> Function() onVoiceStop;
  final VoidCallback? onTyping;
  final bool enabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmoji = false;
  bool _recording = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _showEmoji = false);
  }

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
      if (_showEmoji) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _onEmojiSelected(Emoji emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    _controller
      ..text = text.replaceRange(start, end, emoji.emoji)
      ..selection = TextSelection.collapsed(offset: start + emoji.emoji.length);
    widget.onTyping?.call();
  }

  Future<void> _showAttachSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery photo'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () => Navigator.pop(ctx, 'doc'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'gallery':
        await widget.onImagePicked(ImageSource.gallery);
      case 'camera':
        await widget.onImagePicked(ImageSource.camera);
      case 'video':
        widget.onVideoPicked();
      case 'doc':
        widget.onDocumentPicked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.darkHeader : AppColors.divider;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: barColor,
          padding: EdgeInsets.fromLTRB(
            6,
            6,
            6,
            6 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: widget.enabled ? _toggleEmoji : null,
                icon: Icon(
                  _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  color: chatTheme(context).subtitle,
                ),
              ),
              IconButton(
                onPressed: widget.enabled ? _showAttachSheet : null,
                icon: Icon(Icons.attach_file, color: chatTheme(context).subtitle),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  onChanged: (_) => widget.onTyping?.call(),
                  onSubmitted: (_) => _submit(),
                  onTap: () {
                    if (_showEmoji) setState(() => _showEmoji = false);
                  },
                  decoration: const InputDecoration(hintText: 'Message'),
                  minLines: 1,
                  maxLines: 5,
                ),
              ),
              GestureDetector(
                onLongPressStart: widget.enabled
                    ? (_) {
                        setState(() => _recording = true);
                        widget.onVoiceStart();
                      }
                    : null,
                onLongPressEnd: widget.enabled
                    ? (_) async {
                        setState(() => _recording = false);
                        await widget.onVoiceStop();
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _recording ? Icons.mic : Icons.mic_none,
                    color: _recording ? Colors.red : chatTheme(context).subtitle,
                  ),
                ),
              ),
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
        ),
        if (_showEmoji)
          SizedBox(
            height: 260,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) => _onEmojiSelected(emoji),
              config: Config(height: 260, checkPlatformCompatibility: !kIsWeb),
            ),
          ),
      ],
    );
  }
}
