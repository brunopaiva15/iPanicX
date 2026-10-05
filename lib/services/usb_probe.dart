import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app/host_platform.dart';
import 'command_runner.dart';

/// What the host OS itself sees on USB, independently of libimobiledevice.
class UsbPresence {
  const UsbPresence({
    required this.present,
    this.driverProblem = false,
    this.details = '',
  });

  /// An Apple iOS device (vendor 0x05AC) is attached.
  final bool present;

  /// Windows reports it with a device-manager error (driver missing / failed).
  final bool driverProblem;

  /// Raw lines from the OS query, for the technical section.
  final String details;
}

/// Is Apple's Windows USB stack (Apple Devices or iTunes) installed?
class AppleSupport {
  const AppleSupport({
    required this.installed,
    this.serviceRunning = false,
    this.details = '',
  });

  /// The Apple Mobile Device service, or an Apple Devices / iTunes package,
  /// exists on this PC.
  final bool installed;
  final bool serviceRunning;

  /// Raw query output, for the technical section.
  final String details;
}

/// Host-side checks run when `idevice_id` lists nothing, so the app can tell
/// "nothing plugged in" apart from "plugged in but invisible to usbmuxd".
class UsbProbe {
  UsbProbe({
    CommandRunner runner = const ProcessCommandRunner(),
    Map<String, String>? environment,
    bool? isWindows,
    bool? isMacOS,
  }) : _runner = runner,
       _env = environment ?? Platform.environment,
       _windows = isWindows ?? HostPlatform.isWindows,
       _mac = isMacOS ?? Platform.isMacOS;

  final CommandRunner _runner;
  final Map<String, String> _env;
  final bool _windows;
  final bool _mac;

  static const _queryTimeout = Duration(seconds: 10);

  /// Where libusbmuxd connects: `USBMUXD_SOCKET_ADDRESS`, else
  /// `127.0.0.1:27015` (Apple Mobile Device Service) on Windows and
  /// `/var/run/usbmuxd` elsewhere.
  String get usbmuxAddress {
    final override = _env['USBMUXD_SOCKET_ADDRESS'];
    if (override != null && override.isNotEmpty) return override;
    return _windows ? '127.0.0.1:27015' : '/var/run/usbmuxd';
  }

  /// Whether usbmuxd / Apple Mobile Device Service accepts connections.
  /// `null` when it could not be determined.
  Future<bool?> usbmuxReachable() async {
    final address = usbmuxAddress;
    try {
      final Socket socket;
      final tcp = RegExp(r'^(.+):(\d+)$').firstMatch(address);
      if (tcp != null && !address.startsWith('/')) {
        socket = await Socket.connect(
          tcp.group(1)!,
          int.parse(tcp.group(2)!),
          timeout: const Duration(seconds: 2),
        );
      } else {
        if (FileSystemEntity.typeSync(address) ==
            FileSystemEntityType.notFound) {
          return false;
        }
        socket = await Socket.connect(
          InternetAddress(address, type: InternetAddressType.unix),
          0,
          timeout: const Duration(seconds: 2),
        );
      }
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } catch (_) {
      return null;
    }
  }

  /// Asks the OS whether an iPhone/iPad is attached. `null` when this OS has
  /// no supported query or the query failed.
  Future<UsbPresence?> appleDeviceOnUsb() async {
    try {
      if (_windows) return await _windowsPresence();
      if (_mac) return await _macPresence();
    } catch (_) {
      // Best effort only.
    }
    return null;
  }

  /// Win32_PnPEntity with Apple's vendor ID and an iOS product ID (0x12xx).
  /// ConfigManagerErrorCode 0 = working, anything else (28 = no driver,
  /// 10 = cannot start…) is a driver problem.
  static const windowsQuery =
      r'Get-CimInstance Win32_PnPEntity -Filter "PNPDeviceID LIKE '
      r"'USB\\VID_05AC&PID_12%'"
      r'" | ForEach-Object { "$($_.ConfigManagerErrorCode)|$($_.Name)|$($_.PNPDeviceID)" }';

  Future<UsbPresence?> _windowsPresence() async {
    final r = await _powershell(windowsQuery);
    if (r == null || !r.ok) return null;
    return parseWindowsPnp(r.stdout);
  }

  /// Apple Mobile Device service (iTunes, or packaged with Apple Devices)
  /// and Apple Devices / iTunes Store packages of the current user.
  static const appleSupportQuery =
      r"$s = Get-Service | Where-Object { $_.Name -like '*Apple Mobile Device*' -or $_.DisplayName -like '*Apple Mobile Device*' } | Select-Object -First 1; "
      r'"service=$($s.Name)|$($s.Status)"; '
      r"$p = Get-AppxPackage -Name 'AppleInc.*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'AppleDevices|iTunes' } | ForEach-Object { $_.Name }; "
      r'"packages=$($p -join ",")"';

  /// Windows only; `null` elsewhere or when the query fails.
  Future<AppleSupport?> appleSupport() async {
    if (!_windows) return null;
    try {
      final r = await _powershell(appleSupportQuery);
      if (r == null || !r.ok) return null;
      return parseAppleSupport(r.stdout);
    } catch (_) {
      return null;
    }
  }

  Future<CommandResult?> _powershell(String script) {
    // -EncodedCommand avoids every quoting issue between Dart, CreateProcess
    // and PowerShell (UTF-16LE, base64).
    final utf16 = <int>[];
    for (final unit in script.codeUnits) {
      utf16
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    }
    return _runner.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      base64.encode(utf16),
    ], timeout: _queryTimeout);
  }

  Future<UsbPresence?> _macPresence() async {
    final r = await _runner.run('/usr/sbin/ioreg', [
      '-p',
      'IOUSB',
      '-l',
      '-w0',
    ], timeout: _queryTimeout);
    if (!r.ok) return null;
    return parseMacIoreg(r.stdout);
  }
}

/// Parses `<errorCode>|<name>|<pnpId>` lines from [UsbProbe.windowsQuery].
UsbPresence parseWindowsPnp(String stdout) {
  final lines = const LineSplitter()
      .convert(stdout)
      .map((l) => l.trim())
      .where((l) => l.split('|').length >= 3)
      .toList();
  final problem = lines.any((l) {
    final code = int.tryParse(l.split('|').first.trim());
    return code != null && code != 0;
  });
  return UsbPresence(
    present: lines.isNotEmpty,
    driverProblem: problem,
    details: lines.join('\n'),
  );
}

/// Parses the `service=<name>|<status>` / `packages=<a,b>` lines of
/// [UsbProbe.appleSupportQuery]. `null` when the output is not recognised.
AppleSupport? parseAppleSupport(String stdout) {
  String? service, status, packages;
  for (final raw in const LineSplitter().convert(stdout)) {
    final line = raw.trim();
    if (line.startsWith('service=')) {
      final v = line.substring(8).split('|');
      service = v.first.trim();
      status = v.length > 1 ? v[1].trim() : '';
    } else if (line.startsWith('packages=')) {
      packages = line.substring(9).trim();
    }
  }
  if (service == null && packages == null) return null;
  final hasService = service != null && service.isNotEmpty;
  final hasPackage = packages != null && packages.isNotEmpty;
  return AppleSupport(
    installed: hasService || hasPackage,
    serviceRunning: hasService && status!.toLowerCase() == 'running',
    details: [
      'Apple Mobile Device service: ${hasService ? '$service ($status)' : 'not installed'}',
      'Apple packages: ${hasPackage ? packages : 'none'}',
    ].join('\n'),
  );
}

/// Looks for iPhone/iPad/iPod entries in `ioreg -p IOUSB -l -w0`.
UsbPresence parseMacIoreg(String stdout) {
  final names = RegExp(
    r'"USB Product Name" = "((?:iPhone|iPad|iPod)[^"]*)"',
  ).allMatches(stdout).map((m) => m.group(1)!).toList();
  return UsbPresence(present: names.isNotEmpty, details: names.join('\n'));
}
