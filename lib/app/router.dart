import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../ui/screens/device_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/panic_detail_screen.dart';
import '../ui/screens/raw_panic_screen.dart';

/// Named routes. Arguments are passed via [RouteSettings.arguments].
class AppRouter {
  const AppRouter._();

  static const home = '/';
  static const device = '/device';
  static const panic = '/panic';
  static const raw = '/panic/raw';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      device => const DeviceScreen(),
      panic => PanicDetailScreen(panic: settings.arguments! as AnalyzedPanic),
      raw => RawPanicScreen(panic: settings.arguments! as AnalyzedPanic),
      _ => const HomeScreen(),
    };
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }

  static Future<void> openPanic(BuildContext context, AnalyzedPanic panic) =>
      Navigator.of(context).pushNamed(AppRouter.panic, arguments: panic);

  static Future<void> openRaw(BuildContext context, AnalyzedPanic panic) =>
      Navigator.of(context).pushNamed(AppRouter.raw, arguments: panic);

  static Future<void> openDevice(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRouter.device);
}
