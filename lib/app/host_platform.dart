import 'dart:io';

/// Host OS facts used for wording and tool lookup.
///
/// [isWindows] is overridable so tests (which run on Linux/macOS) can cover
/// the Windows paths and texts.
class HostPlatform {
  const HostPlatform._();

  static bool isWindows = Platform.isWindows;

  /// "Mac" / "PC" in user-facing sentences.
  static String get computer => isWindows ? 'PC' : 'Mac';

  static String get fileManager => isWindows ? 'File Explorer' : 'Finder';

  static String get revealLabel => 'Show in $fileManager';

  /// How to get the libimobiledevice tools on this OS.
  static String get installCommand => isWindows
      ? 'pacman -S mingw-w64-ucrt-x86_64-libimobiledevice'
      : 'brew install libimobiledevice';

  static String get installHint => isWindows
      ? 'Install “Apple Devices” (Microsoft Store) or iTunes for the iPhone '
            'USB driver, then libimobiledevice with MSYS2, or use a build of '
            'iPaniX that bundles the tools (see README).'
      : 'Install it with Homebrew, or build iPaniX with the bundled tools '
            '(see README).';

  /// Explanation when usbmuxd / Apple Mobile Device Service is unreachable.
  static String get usbServiceHint => isWindows
      ? 'Unable to list USB devices. Make sure “Apple Devices” or iTunes is '
            'installed and the Apple Mobile Device Service is running.'
      : 'Unable to list USB devices. Is usbmuxd running?';

  /// Bullet shown under "plugged in but not detected?".
  static String get driverHint => isWindows
      ? '• Windows needs Apple’s USB driver and the Apple Mobile Device '
            'Service: install “Apple Devices” from the Microsoft Store (or '
            'iTunes), open it once, then unplug and reconnect the iPhone.'
      : '• Try another USB port or adapter, then unplug and reconnect.';

  /// The OS sees an iPhone but usbmuxd does not list it.
  static String get notRecognizedHint => isWindows
      ? 'Windows sees an iPhone on USB, but the Apple Mobile Device Service '
            'does not list it. Unlock the iPhone, unplug and reconnect it. '
            'If it persists, open “Apple Devices” (or iTunes) once, or '
            'restart “Apple Mobile Device Service” in services.msc.'
      : 'macOS sees an iPhone on USB, but usbmuxd does not list it. Unlock '
            'the iPhone, then unplug and reconnect it.';

  /// Windows reports the iPhone with a device-manager error.
  static const driverProblemHint =
      'Windows sees the iPhone, but its Apple USB driver is missing or not '
      'working. Install or repair “Apple Devices” (Microsoft Store) or '
      'iTunes, then unplug and reconnect the iPhone. In Device Manager it '
      'appears with a warning sign under “Portable Devices” or “Universal '
      'Serial Bus controllers”.';
}
