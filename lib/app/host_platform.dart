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
}
