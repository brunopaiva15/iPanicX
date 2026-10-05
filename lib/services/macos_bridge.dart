import 'package:flutter/services.dart';

import 'platform_bridge.dart';

/// Dart side of `macos/Runner/IPhoneBridge.swift` and `DeviceWatcher.swift`.
///
/// Every call degrades gracefully when the native side is missing (tests,
/// other platforms): methods return null / false instead of throwing.
class MacOSBridge implements PlatformBridge {
  @override
  Future<bool> openAppleDevicesInStore() async => false;

  @override
  Future<bool> openServicesConsole() async => false;

  @override
  Future<bool> openDeviceManager() async => false;

  const MacOSBridge();

  static const _methods = MethodChannel('ipanix/bridge');
  static const _usbEvents = EventChannel('ipanix/usb_events');

  /// Fires whenever an Apple USB device is attached or detached (IOKit).
  @override
  Stream<void> get usbDeviceEvents => _usbEvents
      .receiveBroadcastStream()
      .map<void>((_) {})
      .handleError((Object _) {}, test: (e) => e is MissingPluginException);

  /// Shows an NSSavePanel and writes [contents] to the chosen file.
  /// Returns the saved path, or null if cancelled / unavailable.
  @override
  Future<String?> saveTextFile({
    required String suggestedName,
    required String contents,
  }) => _invoke<String>('saveTextFile', {
    'suggestedName': suggestedName,
    'contents': contents,
  });

  /// Shows an NSOpenPanel for `.ips` files. Returns the chosen path.
  @override
  Future<String?> pickIpsFile() => _invoke<String>('pickIpsFile');

  @override
  Future<bool> revealInFinder(String path) async =>
      await _invoke<bool>('revealInFinder', {'path': path}) ?? false;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
