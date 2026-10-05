import 'package:flutter/material.dart';

import '../diagnostics/health_report.dart';
import '../models/diagnostic_result.dart';

/// Tokens taken from Codenotch (MIT, github.com/vinzdg/codenotch):
/// the settings window's solid palette (windows/codenotch/ui/settings.html,
/// `body.solid`) and the notch palette (Sources/DesignSystem/Palette.swift).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.pane,
    required this.side,
    required this.group,
    required this.line,
    required this.sep,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.btn,
    required this.btnHover,
    required this.segBg,
    required this.hover,
    required this.selSoft,
    required this.dangerBg,
    required this.danger,
  });

  final Color background;
  final Color pane;
  final Color side;
  final Color group;
  final Color line;
  final Color sep;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color btn;
  final Color btnHover;
  final Color segBg;
  final Color hover;
  final Color selSoft;
  final Color dangerBg;
  final Color danger;

  static const dark = AppColors(
    background: Color(0xFF2B2B2E),
    pane: Color(0xFF3D3D40),
    side: Color(0xFF1F2022),
    group: Color(0xFF48484B),
    line: Color(0x14FFFFFF),
    sep: Color(0x14FFFFFF),
    text: Color(0xFFF2F2F4),
    text2: Color(0x9EEBEBF5),
    text3: Color(0x61EBEBF5),
    accent: Color(0xFF0A7AFF),
    btn: Color(0x1AFFFFFF),
    btnHover: Color(0x29FFFFFF),
    segBg: Color(0x17FFFFFF),
    hover: Color(0x0FFFFFFF),
    selSoft: Color(0x14FFFFFF),
    dangerBg: Color(0x24FF6363),
    danger: Color(0xFFFF8A8A),
  );

  static const light = AppColors(
    background: Color(0xFFF0F0F2),
    pane: Color(0xFFF0F0F2),
    side: Color(0xFFE2E2E6),
    group: Color(0xFFFFFFFF),
    line: Color(0x12000000),
    sep: Color(0x12000000),
    text: Color(0xFF1D1D1F),
    text2: Color(0xB33C3C43),
    text3: Color(0x733C3C43),
    accent: Color(0xFF0A7AFF),
    btn: Color(0x0D000000),
    btnHover: Color(0x17000000),
    segBg: Color(0x0F000000),
    hover: Color(0x0A000000),
    selSoft: Color(0x0D000000),
    dangerBg: Color(0x1AC42B1C),
    danger: Color(0xFFC42B1C),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// The notch is black whatever the appearance (Palette.notch / Palette.card).
abstract final class Notch {
  static const surface = Color(0xFF000000);
  static const ink = Color(0xFFFFFFFF);
  static const ink2 = Color(0xFF808080);

  /// White at 18.8% (ring) / 17.6% (bar): #303030 / #2D2D2D over black.
  static const ringTrack = Color(0x30FFFFFF);
  static const barTrack = Color(0x2DFFFFFF);

  static const ample = Color(0xFF00FF88);
  static const watch = Color(0xFFF2FF00);
  static const critical = Color(0xFFFF3F00);

  /// UsageBand.band with Codenotch's default limits (watch 50%, critical 70%).
  static Color band(double fraction) => fraction < 0.5
      ? ample
      : fraction < 0.7
      ? watch
      : critical;

  static Color severity(Severity s) => switch (s) {
    Severity.high => critical,
    Severity.medium => watch,
    Severity.low => ample,
    Severity.unknown => ink2,
  };
}

/// Body text is 13.5 like the settings window.
const double kBodySize = 13.5;

const monospaceFont = 'Menlo';
const monospaceFallback = [
  'SF Mono',
  'Cascadia Mono',
  'Consolas',
  'DejaVu Sans Mono',
  'monospace',
];

TextStyle monoStyle(BuildContext context, {double size = 12, Color? color}) =>
    TextStyle(
      fontFamily: monospaceFont,
      fontFamilyFallback: monospaceFallback,
      fontSize: size,
      height: 1.4,
      color: color ?? AppColors.of(context).text,
    );

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? AppColors.light : AppColors.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(primary: c.accent, surface: c.group, onSurface: c.text),
    scaffoldBackgroundColor: c.background,
    canvasColor: c.pane,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: c.hover,
    visualDensity: VisualDensity.compact,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: c.accent.withValues(alpha: 0.35),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: c.side,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.line),
      ),
      textStyle: TextStyle(color: c.text2, fontSize: 12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.group,
      textStyle: TextStyle(color: c.text, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.line),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Check status colours, readable on the light and dark panes (Apple's
/// system green / orange, and the pane's danger red).
abstract final class StatusColors {
  static const ok = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);

  static Color of(CheckStatus s, AppColors c) => switch (s) {
    CheckStatus.ok => ok,
    CheckStatus.warning => warning,
    CheckStatus.problem => c.danger,
    CheckStatus.info => c.accent,
    CheckStatus.unavailable => c.text3,
  };
}
