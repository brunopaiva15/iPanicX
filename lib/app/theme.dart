import 'package:flutter/material.dart';

import '../models/diagnostic_result.dart';

/// Design tokens, after Codenotch's design system (MIT,
/// github.com/vinzdg/codenotch): pure-black surfaces, white ink, #808080
/// secondary ink, translucent white tracks, and the three signal colours
/// ample #00FF88 / watch #F2FF00 / critical #FF3F00. Light values follow the
/// same project's light palette (contrast ≥ 3:1 on white).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.window,
    required this.sidebar,
    required this.card,
    required this.raised,
    required this.border,
    required this.hairline,
    required this.track,
    required this.ink,
    required this.secondaryText,
    required this.tertiaryText,
    required this.critical,
    required this.watch,
    required this.ample,
    required this.blue,
    required this.grey,
    required this.codeBackground,
    required this.onSignal,
  });

  /// Main pane background.
  final Color window;
  final Color sidebar;

  /// Cards / groups ("the notch").
  final Color card;

  /// Rows / controls on top of a card.
  final Color raised;
  final Color border;
  final Color hairline;

  /// Ring and bar tracks.
  final Color track;
  final Color ink;
  final Color secondaryText;
  final Color tertiaryText;
  final Color critical;
  final Color watch;
  final Color ample;
  final Color blue;
  final Color grey;
  final Color codeBackground;

  /// Text on a filled signal colour.
  final Color onSignal;

  // Legacy names used across the UI.
  Color get red => critical;
  Color get orange => watch;
  Color get green => ample;

  static const dark = AppColors(
    window: Color(0xFF000000),
    sidebar: Color(0xFF0B0B0C),
    card: Color(0xFF111112),
    raised: Color(0xFF1A1A1C),
    border: Color(0x1FFFFFFF),
    hairline: Color(0x14FFFFFF),
    track: Color(0x30FFFFFF), // white @ 18.8%: #303030 over black
    ink: Color(0xFFFFFFFF),
    secondaryText: Color(0xFF808080),
    tertiaryText: Color(0xFF5C5C5E),
    critical: Color(0xFFFF3F00),
    watch: Color(0xFFF2FF00),
    ample: Color(0xFF00FF88),
    blue: Color(0xFF0A84FF),
    grey: Color(0xFF808080),
    codeBackground: Color(0xFF0A0A0B),
    onSignal: Color(0xFF000000),
  );

  static const light = AppColors(
    window: Color(0xFFF0F0F2),
    sidebar: Color(0xFFE6E6EA),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFF4F4F6),
    border: Color(0x14000000),
    hairline: Color(0x12000000),
    track: Color(0x29000000), // black @ 16%
    ink: Color(0xFF000000),
    secondaryText: Color(0xFF6B6B6B),
    tertiaryText: Color(0xFF9A9A9E),
    critical: Color(0xFFFF3F00),
    watch: Color(0xFFB08800),
    ample: Color(0xFF00A356),
    blue: Color(0xFF0A7AFF),
    grey: Color(0xFF8E8E93),
    codeBackground: Color(0xFFF6F6F8),
    onSignal: Color(0xFFFFFFFF),
  );

  Color severity(Severity s) => switch (s) {
    Severity.high => critical,
    Severity.medium => watch,
    Severity.low => ample,
    Severity.unknown => grey,
  };

  Color confidence(Confidence c) => switch (c) {
    Confidence.high => ample,
    Confidence.medium => watch,
    Confidence.low => watch,
    Confidence.none => grey,
  };

  /// Codenotch-style band colour for a share (green → yellow → red).
  Color band(double fraction) => fraction >= 0.75
      ? critical
      : fraction >= 0.4
      ? watch
      : ample;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Wordmark font (Orbitron, SIL OFL — assets/fonts/Orbitron-OFL.txt).
const wordmarkFont = 'Orbitron';

const monospaceFont = 'Menlo';
const monospaceFallback = [
  'SF Mono',
  'Monaco',
  'Cascadia Mono',
  'Consolas',
  'DejaVu Sans Mono',
  'Courier New',
  'monospace',
];

TextStyle monoStyle(BuildContext context, {double size = 12, Color? color}) =>
    TextStyle(
      fontFamily: monospaceFont,
      fontFamilyFallback: monospaceFallback,
      fontSize: size,
      height: 1.45,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// Large semibold numerals (the "73%" under a ring).
TextStyle numeralStyle(
  BuildContext context, {
  double size = 28,
  Color? color,
}) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.5,
  height: 1.05,
  color: color ?? AppColors.of(context).ink,
  fontFeatures: const [FontFeature.tabularFigures()],
);

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? AppColors.light : AppColors.dark;
  final scheme = ColorScheme.fromSeed(seedColor: c.blue, brightness: brightness)
      .copyWith(
        primary: c.ink,
        onPrimary: c.window == AppColors.dark.window
            ? Colors.black
            : Colors.white,
        surface: c.card,
        onSurface: c.ink,
        error: c.critical,
        outlineVariant: c.border,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: c.window,
    canvasColor: c.window,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        fontSize: 32,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
    ),
    dividerTheme: DividerThemeData(color: c.hairline, space: 1, thickness: 1),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: c.border),
      ),
    ),
    // Primary action: a solid ink pill (white on black, black on white).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.ink,
        foregroundColor: c.window == AppColors.dark.window
            ? Colors.black
            : Colors.white,
        disabledBackgroundColor: c.track,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    // Secondary: translucent pill.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        backgroundColor: c.raised,
        side: BorderSide(color: c.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.secondaryText,
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: c.secondaryText),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.ink,
      linearTrackColor: c.track,
      circularTrackColor: c.track,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dark.border),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: c.border),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 440,
      backgroundColor: Colors.black,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      actionTextColor: AppColors.dark.ample,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.dark.border),
      ),
    ),
  );
}
