import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

class WhatsAppChatBackground extends StatelessWidget {
  const WhatsAppChatBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wallpaper = chatTheme(context).wallpaper;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(color: wallpaper),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DoodlePainter(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : AppColors.primary.withValues(alpha: 0.04),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 48.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x + 12, y + 12), 2, paint);
        canvas.drawRect(
          Rect.fromLTWH(x + 28, y + 24, 8, 8),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
