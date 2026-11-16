import 'package:flutter/material.dart';

/// SingLearn visual identity: teal (music/learning) with warm amber accents.
class AppTheme {
  static const seed = Color(0xFF00897B);

  static ThemeData _base(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: b,
      tertiary: const Color(0xFFFFB300),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
    );
  }

  static final light = _base(Brightness.light);
  static final dark = _base(Brightness.dark);

  /// Colour for a CEFR level badge.
  static Color levelColor(String level) => switch (level) {
        'A1' => const Color(0xFF43A047),
        'A2' => const Color(0xFF1E88E5),
        'B1' => const Color(0xFFFB8C00),
        'B2' => const Color(0xFFE53935),
        _ => Colors.grey,
      };
}
