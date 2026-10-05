import '../app/host_platform.dart';
import 'macos_bridge.dart';
import 'windows_bridge.dart';

/// Native desktop services (file dialogs, file manager, USB notifications).
///
/// Implementations:
///  * [MacOSBridge] — Swift (`macos/Runner/IPhoneBridge.swift`,
///    `DeviceWatcher.swift`) through platform channels;
///  * [WindowsBridge] — `file_selector` dialogs and `explorer.exe`.
///
/// All methods degrade gracefully (null / false) when unavailable.
abstract class PlatformBridge {
  const PlatformBridge();

  factory PlatformBridge.forHost() =>
      HostPlatform.isWindows ? const WindowsBridge() : const MacOSBridge();

  /// Fires when an Apple USB device is attached or detached. May never fire
  /// (the device service also polls).
  Stream<void> get usbDeviceEvents;

  /// Asks where to save [contents] and writes it. Returns the saved path, or
  /// null if cancelled / unavailable.
  Future<String?> saveTextFile({
    required String suggestedName,
    required String contents,
  });

  /// Lets the user choose a report file. Returns its path or null.
  Future<String?> pickIpsFile();

  /// Shows [path] in Finder / File Explorer.
  Future<bool> revealInFinder(String path);

  /// Opens the Microsoft Store on “Apple Devices” (iPhone USB driver and
  /// Apple Mobile Device Service). Windows only; false elsewhere.
  Future<bool> openAppleDevicesInStore();

  /// Opens the Windows Services console (services.msc). Windows only.
  Future<bool> openServicesConsole();

  /// Opens Device Manager (devmgmt.msc). Windows only.
  Future<bool> openDeviceManager();
}
