import 'dart:convert';
import 'dart:io';

import '../l10n/strings.dart';
import '../models/device_status.dart';
import '../models/diagnostic_file.dart';
import '../models/iphone_device.dart';

/// Progress callback while crash reports are copied from the device.
typedef CrashReportProgress = void Function(int filesCopied, String? lastFile);

/// Access to a USB-connected iPhone.
///
/// Implementations: [LibimobiledeviceService] (real device, via the
/// libimobiledevice executables) and [MockIPhoneService] (UI development).
abstract class IPhoneService {
  /// Currently selected device (null when none / not readable).
  Stream<IPhoneDevice?> get connectedDevice;

  /// Detailed connection status, including trust / lock / error states.
  /// Emits the current status first.
  Stream<DeviceStatus> get status;

  DeviceStatus get currentStatus;

  Future<IPhoneDevice?> getCurrentDevice();

  /// Copies every crash/diagnostic report from the device into a local,
  /// app-owned folder (reports are kept on the iPhone) and returns them
  /// newest first.
  Future<List<DiagnosticFile>> getCrashReports({
    CrashReportProgress? onProgress,
  });

  Future<String> readCrashReport(DiagnosticFile file);

  /// Starts watching for devices.
  Future<void> start();

  /// Forces an immediate device lookup (also clears a "pairing denied" block).
  Future<void> refresh();

  /// Asks the device to show the "Trust This Computer?" prompt.
  Future<void> requestPairing();

  /// Human readable description of the backend, shown in About.
  String get backendDescription;

  bool get isMock => false;

  void dispose();
}

enum IPhoneErrorKind {
  noDevice,
  deviceLocked,
  trustRequired,
  pairingDenied,
  communication,
  crashReportsUnavailable,
  toolsUnavailable,
  timeout;

  String get title => tr.errorTitle(name);

  /// Localized explanation; the service's English message is kept for logs.
  String get message => tr.errorMessage(name);
}

/// Error with a user-facing message and (optional) raw technical details.
class IPhoneServiceException implements Exception {
  const IPhoneServiceException(
    this.kind,
    this.message, {
    this.technicalDetails,
  });

  final IPhoneErrorKind kind;
  final String message;
  final String? technicalDetails;

  @override
  String toString() => 'IPhoneServiceException(${kind.name}): $message';
}

/// Reads a copied report as text (tolerates invalid UTF-8).
Future<String> readReportFile(DiagnosticFile file) async {
  try {
    final bytes = await File(file.path).readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  } on FileSystemException catch (e) {
    throw IPhoneServiceException(
      IPhoneErrorKind.crashReportsUnavailable,
      'The report ${file.name} could not be read from disk.',
      technicalDetails: e.toString(),
    );
  }
}

/// Recursively lists copied report files, newest first.
Future<List<DiagnosticFile>> listReportFiles(Directory root) async {
  final files = <DiagnosticFile>[];
  if (!await root.exists()) return files;
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name.startsWith('.')) continue;
    final stat = await entity.stat();
    files.add(
      DiagnosticFile.fromPath(
        path: entity.path,
        rootDirectory: root.path,
        sizeBytes: stat.size,
        modified: stat.modified,
      ),
    );
  }
  files.sort(DiagnosticFile.newestFirst);
  return files;
}
