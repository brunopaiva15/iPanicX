import 'package:flutter/material.dart';

import '../models/diagnostic_result.dart';

/// Extra colors not covered by [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.window,
    required this.card,
    required this.border,
    required this.secondaryText,
    required this.tertiaryText,
    required this.red,
    required this.orange,
    required this.green,
    required this.blue,
    required this.grey,
    required this.codeBackground,
  });

  final Color window;
  final Color card;
  final Color border;
  final Color secondaryText;
  final Color tertiaryText;
  final Color red;
  final Color orange;
  final Color green;
  final Color blue;
  final Color grey;
  final Color codeBackground;

  static const light = AppColors(
    window: Color(0xFFF5F5F7),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE3E3E8),
    secondaryText: Color(0xFF6E6E73),
    tertiaryText: Color(0xFF8E8E93),
    red: Color(0xFFFF3B30),
    orange: Color(0xFFFF9500),
    green: Color(0xFF34C759),
    blue: Color(0xFF0071E3),
    grey: Color(0xFF8E8E93),
    codeBackground: Color(0xFFF2F2F5),
  );

  static const dark = AppColors(
    window: Color(0xFF1C1C1E),
    card: Color(0xFF2C2C2E),
    border: Color(0xFF3A3A3C),
    secondaryText: Color(0xFFA1A1A6),
    tertiaryText: Color(0xFF7C7C80),
    red: Color(0xFFFF453A),
    orange: Color(0xFFFF9F0A),
    green: Color(0xFF30D158),
    blue: Color(0xFF0A84FF),
    grey: Color(0xFF8E8E93),
    codeBackground: Color(0xFF232325),
  );

  Color severity(Severity s) => switch (s) {
    Severity.high => red,
    Severity.medium => orange,
    Severity.low => green,
    Severity.unknown => grey,
  };

  Color confidence(Confidence c) => switch (c) {
    Confidence.high => green,
    Confidence.medium => orange,
    Confidence.low => orange,
    Confidence.none => grey,
  };

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

const monospaceFont = 'Menlo';
const monospaceFallback = [
  'SF Mono',
  'Monaco',
  'Cascadia Mono',
  'Consolas',
  'Courier New',
  'monospace',
];

TextStyle monoStyle(BuildContext context, {double size = 12}) => TextStyle(
  fontFamily: monospaceFont,
  fontFamilyFallback: monospaceFallback,
  fontSize: size,
  height: 1.45,
  color: Theme.of(context).colorScheme.onSurface,
);

ThemeData buildTheme(Brightness brightness) {
  final colors = brightness == Brightness.light
      ? AppColors.light
      : AppColors.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: colors.blue,
        brightness: brightness,
      ).copyWith(
        primary: colors.blue,
        onPrimary: Colors.white,
        surface: colors.card,
        error: colors.red,
        outlineVariant: colors.border,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: colors.window,
    extensions: [colors],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  final text = base.textTheme;
  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        fontSize: 30,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
    ),
    dividerTheme: DividerThemeData(
      color: colors.border,
      space: 1,
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      color: colors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: colors.border),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 600),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
    ),
  );
}
