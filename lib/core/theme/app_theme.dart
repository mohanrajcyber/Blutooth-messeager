import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        scaffold: AppColors.chatBackground,
        header: AppColors.headerBackground,
        bubbleSent: AppColors.sentBubble,
        bubbleReceived: AppColors.receivedBubble,
        inputFill: Colors.white,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scaffold: AppColors.darkBackground,
        header: AppColors.darkHeader,
        bubbleSent: AppColors.darkSentBubble,
        bubbleReceived: AppColors.darkReceivedBubble,
        inputFill: AppColors.darkInput,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color header,
    required Color bubbleSent,
    required Color bubbleReceived,
    required Color inputFill,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: isDark ? AppColors.darkSurface : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: header,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.darkSurface : Colors.white,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkSubtitle : AppColors.subtitle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      listTileTheme: ListTileThemeData(
        textColor: isDark ? Colors.white : Colors.black87,
        iconColor: isDark ? Colors.white70 : AppColors.subtitle,
      ),
      extensions: [
        ChatThemeExtension(
          bubbleSent: bubbleSent,
          bubbleReceived: bubbleReceived,
          wallpaper: isDark
              ? AppColors.darkBackground
              : AppColors.chatBackground,
          subtitle: isDark ? AppColors.darkSubtitle : AppColors.subtitle,
        ),
      ],
    );
  }
}

class ChatThemeExtension extends ThemeExtension<ChatThemeExtension> {
  const ChatThemeExtension({
    required this.bubbleSent,
    required this.bubbleReceived,
    required this.wallpaper,
    required this.subtitle,
  });

  final Color bubbleSent;
  final Color bubbleReceived;
  final Color wallpaper;
  final Color subtitle;

  @override
  ChatThemeExtension copyWith({
    Color? bubbleSent,
    Color? bubbleReceived,
    Color? wallpaper,
    Color? subtitle,
  }) {
    return ChatThemeExtension(
      bubbleSent: bubbleSent ?? this.bubbleSent,
      bubbleReceived: bubbleReceived ?? this.bubbleReceived,
      wallpaper: wallpaper ?? this.wallpaper,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  @override
  ChatThemeExtension lerp(ThemeExtension<ChatThemeExtension>? other, double t) {
    if (other is! ChatThemeExtension) return this;
    return ChatThemeExtension(
      bubbleSent: Color.lerp(bubbleSent, other.bubbleSent, t)!,
      bubbleReceived: Color.lerp(bubbleReceived, other.bubbleReceived, t)!,
      wallpaper: Color.lerp(wallpaper, other.wallpaper, t)!,
      subtitle: Color.lerp(subtitle, other.subtitle, t)!,
    );
  }
}

ChatThemeExtension chatTheme(BuildContext context) =>
    Theme.of(context).extension<ChatThemeExtension>()!;
