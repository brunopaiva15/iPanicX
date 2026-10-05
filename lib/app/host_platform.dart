import 'dart:io';

import '../l10n/strings.dart';

/// Host OS facts used for wording and tool lookup.
///
/// [isWindows] is overridable so tests (which run on Linux/macOS) can cover
/// the Windows paths and texts.
class HostPlatform {
  const HostPlatform._();

  static bool isWindows = Platform.isWindows;

  /// "Mac" / "PC" in user-facing sentences.
  static String get computer => isWindows ? 'PC' : 'Mac';

  static String get revealLabel =>
      isWindows ? tr.revealInExplorer : tr.revealInFinder;

  /// How to get the libimobiledevice tools on this OS.
  static String get installCommand => isWindows
      ? 'pacman -S mingw-w64-ucrt-x86_64-libimobiledevice'
      : 'brew install libimobiledevice';

  static String get installHint =>
      isWindows ? tr.installHintWindows : tr.installHintMac;

  /// Explanation when usbmuxd / Apple Mobile Device Service is unreachable.
  static String get usbServiceHint =>
      isWindows ? tr.usbServiceWindows : tr.usbServiceMac;

  static String get usbServiceTitle =>
      isWindows ? tr.usbServiceTitleWindows : tr.usbServiceTitleMac;

  /// What to do when usbmuxd / Apple Mobile Device Service is unreachable.
  static String get usbServiceSteps =>
      isWindows ? tr.usbServiceStepsWindows : tr.usbServiceMac;

  /// Bullet shown under "plugged in but not detected?".
  static String get driverHint =>
      isWindows ? tr.driverHintWindows : tr.driverHintMac;

  /// The OS sees an iPhone but usbmuxd does not list it.
  static String get notRecognizedHint =>
      isWindows ? tr.notRecognizedWindows : tr.notRecognizedMac;

  /// Windows reports the iPhone with a device-manager error.
  static String get driverProblemHint => tr.driverProblem;
}
