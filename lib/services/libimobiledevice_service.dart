import 'dart:async';
import 'dart:io';

import '../models/device_status.dart';
import '../models/diagnostic_file.dart';
import '../models/iphone_device.dart';
import 'command_runner.dart';
import 'iphone_service.dart';
import 'tool_locator.dart';

/// Real device access through the libimobiledevice command-line tools
/// (`idevice_id`, `ideviceinfo`, `idevicecrashreport`, `idevicepair`).
///
/// V0 choice: shelling out keeps the bridge trivial. Every call goes through
/// [CommandRunner], so a Dart FFI / Swift implementation can replace it later
/// without touching the UI.
class LibimobiledeviceService implements IPhoneService {
  LibimobiledeviceService({
    CommandRunner? runner,
    ToolLocator? locator,
    Stream<void>? usbEvents,
    this.pollInterval = const Duration(seconds: 2),
    Directory? workRoot,
  }) : _runner = runner ?? const ProcessCommandRunner(),
       _locator = locator ?? ToolLocator(),
       // ignore: prefer_initializing_formals
       _usbEvents = usbEvents,
       _workRoot =
           workRoot ??
           Directory('${Directory.systemTemp.path}/iPaniX/CrashReports');

  final CommandRunner _runner;
  final ToolLocator _locator;
  final Stream<void>? _usbEvents;
  final Directory _workRoot;
  final Duration pollInterval;

  static const _listTimeout = Duration(seconds: 5);
  static const _infoTimeout = Duration(seconds: 12);
  static const _crashTimeout = Duration(minutes: 10);

  final _controller = StreamController<DeviceStatus>.broadcast();
  DeviceStatus _status = const DeviceStatus.searching();
  Timer? _timer;
  StreamSubscription<void>? _usbSub;
  bool _polling = false;
  bool _pollAgain = false;
  bool _copying = false;

  /// UDID for which the user denied pairing; not retried automatically to
  /// avoid re-prompting in a loop.
  String? _deniedUdid;

  @override
  String get backendDescription {
    final path = _locator.find('idevice_id');
    return path == null
        ? 'libimobiledevice (not found)'
        : 'libimobiledevice (${File(path).parent.path})';
  }

  @override
  bool get isMock => false;

  @override
  DeviceStatus get currentStatus => _status;

  @override
  Stream<DeviceStatus> get status async* {
    yield _status;
    yield* _controller.stream;
  }

  @override
  Stream<IPhoneDevice?> get connectedDevice =>
      status.map((s) => s.isConnected ? s.device : null).distinct();

  @override
  Future<IPhoneDevice?> getCurrentDevice() async {
    if (_status.state == DeviceConnectionState.searching) await refresh();
    return _status.isConnected ? _status.device : null;
  }

  @override
  Future<void> start() async {
    _usbSub ??= _usbEvents?.listen((_) => unawaited(_poll(force: true)));
    _timer ??= Timer.periodic(pollInterval, (_) => unawaited(_poll()));
    await _poll(force: true);
  }

  @override
  Future<void> refresh() {
    _deniedUdid = null;
    return _poll(force: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _usbSub?.cancel();
    _controller.close();
  }

  void _emit(DeviceStatus s) {
    if (s == _status) return;
    _status = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  // ---------------------------------------------------------------------------
  // Detection

  Future<void> _poll({bool force = false}) async {
    if (_polling) {
      _pollAgain = _pollAgain || force;
      return;
    }
    // Don't compete with idevicecrashreport for the lockdown connection.
    if (_copying && !force) return;
    _polling = true;
    try {
      _emit(await _detect(force: force));
    } catch (e) {
      _emit(
        DeviceStatus(
          state: DeviceConnectionState.communicationError,
          message: 'Unexpected error while looking for devices.',
          technicalDetails: e.toString(),
        ),
      );
    } finally {
      _polling = false;
      if (_pollAgain) {
        _pollAgain = false;
        unawaited(_poll(force: true));
      }
    }
  }

  Future<DeviceStatus> _detect({required bool force}) async {
    final ideviceId = _locator.find('idevice_id');
    final ideviceInfo = _locator.find('ideviceinfo');
    if (ideviceId == null || ideviceInfo == null) {
      return DeviceStatus(
        state: DeviceConnectionState.toolsUnavailable,
        message: 'iPaniX could not find the libimobiledevice tools.',
        technicalDetails:
            'Missing: ${_locator.missingTools().join(', ')}\n'
            'Searched:\n${_locator.searchDirectories.join('\n')}',
      );
    }

    final CommandResult list;
    try {
      list = await _runner.run(ideviceId, ['-l'], timeout: _listTimeout);
    } on CommandNotFoundException catch (e) {
      return DeviceStatus(
        state: DeviceConnectionState.toolsUnavailable,
        message: 'idevice_id could not be started.',
        technicalDetails: e.toString(),
      );
    } on CommandTimeoutException catch (e) {
      return DeviceStatus(
        state: DeviceConnectionState.communicationError,
        message: 'Device lookup timed out.',
        technicalDetails: e.toString(),
      );
    }
    if (!list.ok) {
      final kind = classifyToolError(list.combined);
      if (kind == IPhoneErrorKind.noDevice) {
        return const DeviceStatus.noDevice();
      }
      return DeviceStatus(
        state: DeviceConnectionState.communicationError,
        message: 'Unable to list USB devices. Is usbmuxd running?',
        technicalDetails: list.combined,
      );
    }

    final udids = parseDeviceList(list.stdout);
    if (udids.isEmpty) {
      _deniedUdid = null;
      return const DeviceStatus.noDevice();
    }

    // Keep the current selection stable while it stays connected.
    final previous = _status.udid;
    final udid = (previous != null && udids.contains(previous))
        ? previous
        : udids.first;

    final sameDevice = udid == previous;
    if (!force && sameDevice && _status.isConnected) {
      return _status.deviceCount == udids.length
          ? _status
          : DeviceStatus(
              state: _status.state,
              device: _status.device,
              udid: udid,
              deviceCount: udids.length,
            );
    }
    if (!force && udid == _deniedUdid) {
      return DeviceStatus(
        state: DeviceConnectionState.trustRequired,
        udid: udid,
        device: _status.device,
        deviceCount: udids.length,
        message: _messageFor(IPhoneErrorKind.pairingDenied),
        technicalDetails: _status.technicalDetails,
      );
    }

    final CommandResult info;
    try {
      info = await _runner.run(ideviceInfo, [
        '-u',
        udid,
      ], timeout: _infoTimeout);
    } on CommandTimeoutException catch (e) {
      return DeviceStatus(
        state: DeviceConnectionState.communicationError,
        udid: udid,
        deviceCount: udids.length,
        message: _messageFor(IPhoneErrorKind.timeout),
        technicalDetails: e.toString(),
      );
    } on CommandNotFoundException catch (e) {
      return DeviceStatus(
        state: DeviceConnectionState.toolsUnavailable,
        message: 'ideviceinfo could not be started.',
        technicalDetails: e.toString(),
      );
    }

    final values = parseDeviceInfo(info.stdout);
    if (info.ok && values.containsKey('ProductType')) {
      _deniedUdid = null;
      return DeviceStatus(
        state: DeviceConnectionState.connected,
        device: _deviceFrom(udid, values, paired: true),
        udid: udid,
        deviceCount: udids.length,
      );
    }

    final kind = classifyToolError(info.combined);
    if (kind == IPhoneErrorKind.noDevice) return const DeviceStatus.noDevice();
    if (kind == IPhoneErrorKind.pairingDenied) _deniedUdid = udid;

    // Unpaired devices still expose a few values (`-s`: no pairing).
    IPhoneDevice? partial;
    try {
      final simple = await _runner.run(ideviceInfo, [
        '-u',
        udid,
        '-s',
      ], timeout: _infoTimeout);
      final v = parseDeviceInfo(simple.stdout);
      if (v.isNotEmpty) partial = _deviceFrom(udid, v, paired: false);
    } catch (_) {
      // Partial info is optional.
    }

    return DeviceStatus(
      state: switch (kind) {
        IPhoneErrorKind.trustRequired ||
        IPhoneErrorKind.pairingDenied => DeviceConnectionState.trustRequired,
        IPhoneErrorKind.deviceLocked => DeviceConnectionState.locked,
        _ => DeviceConnectionState.communicationError,
      },
      udid: udid,
      device: partial,
      deviceCount: udids.length,
      message: _messageFor(kind),
      technicalDetails: info.combined.isEmpty
          ? 'ideviceinfo exited with code ${info.exitCode}'
          : info.combined,
    );
  }

  IPhoneDevice _deviceFrom(
    String udid,
    Map<String, String> v, {
    required bool paired,
  }) => IPhoneDevice(
    udid: udid,
    deviceName: v['DeviceName'],
    productType: v['ProductType'],
    productVersion: v['ProductVersion'],
    buildVersion: v['BuildVersion'],
    hardwareModel: v['HardwareModel'],
    isPaired: paired,
  );

  @override
  Future<void> requestPairing() async {
    final udid = _status.udid;
    final pair = _locator.find('idevicepair');
    _deniedUdid = null;
    if (udid != null && pair != null) {
      try {
        await _runner.run(pair, ['-u', udid, 'pair'], timeout: _infoTimeout);
      } catch (_) {
        // The next poll reports the resulting state.
      }
    }
    await _poll(force: true);
  }

  // ---------------------------------------------------------------------------
  // Crash reports

  @override
  Future<List<DiagnosticFile>> getCrashReports({
    CrashReportProgress? onProgress,
  }) async {
    final status = _status;
    final udid = status.udid;
    if (!status.isConnected || udid == null) {
      throw IPhoneServiceException(
        _kindForState(status.state),
        status.message ?? 'Connect and unlock your iPhone first.',
        technicalDetails: status.technicalDetails,
      );
    }
    final tool = _locator.find('idevicecrashreport');
    if (tool == null) {
      throw IPhoneServiceException(
        IPhoneErrorKind.toolsUnavailable,
        'idevicecrashreport could not be found.',
        technicalDetails: 'Searched:\n${_locator.searchDirectories.join('\n')}',
      );
    }

    final target = await _prepareTargetDirectory(udid);
    var copied = 0;
    CommandResult result;
    _copying = true;
    try {
      // -k: keep the reports on the device (copy instead of move).
      result = await _runner.run(
        tool,
        ['-u', udid, '-k', target.path],
        timeout: _crashTimeout,
        onStdoutLine: (line) {
          final m = RegExp(r'^(?:Copy|Move):\s*(.+)$').firstMatch(line.trim());
          if (m != null) {
            copied++;
            onProgress?.call(copied, m.group(1)!.split('/').last);
          }
        },
      );
    } on CommandTimeoutException catch (e) {
      throw IPhoneServiceException(
        IPhoneErrorKind.timeout,
        'Copying crash reports took too long. Keep the iPhone unlocked and try again.',
        technicalDetails: e.toString(),
      );
    } on CommandNotFoundException catch (e) {
      throw IPhoneServiceException(
        IPhoneErrorKind.toolsUnavailable,
        'idevicecrashreport could not be started.',
        technicalDetails: e.toString(),
      );
    } finally {
      _copying = false;
    }

    final files = await listReportFiles(target);
    if (!result.ok && files.isEmpty) {
      final kind = classifyToolError(result.combined);
      throw IPhoneServiceException(
        kind == IPhoneErrorKind.communication
            ? IPhoneErrorKind.crashReportsUnavailable
            : kind,
        kind == IPhoneErrorKind.communication
            ? 'The iPhone refused to share its crash reports.'
            : _messageFor(kind),
        technicalDetails: result.combined,
      );
    }
    return files;
  }

  @override
  Future<String> readCrashReport(DiagnosticFile file) => readReportFile(file);

  /// `<tmp>/iPaniX/CrashReports/<device-key>/<timestamp>`; older scans of
  /// the same device are removed.
  Future<Directory> _prepareTargetDirectory(String udid) async {
    final key = udid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final deviceDir = Directory(
      '${_workRoot.path}/${key.length > 12 ? key.substring(key.length - 12) : key}',
    );
    if (await deviceDir.exists()) {
      await for (final old in deviceDir.list()) {
        try {
          await old.delete(recursive: true);
        } catch (_) {}
      }
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final dir = Directory('${deviceDir.path}/$stamp');
    await dir.create(recursive: true);
    return dir;
  }

  static IPhoneErrorKind _kindForState(DeviceConnectionState s) => switch (s) {
    DeviceConnectionState.trustRequired => IPhoneErrorKind.trustRequired,
    DeviceConnectionState.locked => IPhoneErrorKind.deviceLocked,
    DeviceConnectionState.toolsUnavailable => IPhoneErrorKind.toolsUnavailable,
    DeviceConnectionState.communicationError => IPhoneErrorKind.communication,
    _ => IPhoneErrorKind.noDevice,
  };
}

// -----------------------------------------------------------------------------
// Output parsing (pure functions, unit-tested)

/// Parses `idevice_id -l` output (`<udid>` or `<udid> (USB)` per line).
List<String> parseDeviceList(String stdout) {
  final out = <String>[];
  for (final line in stdout.split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final udid = t.split(RegExp(r'\s+')).first;
    if (!RegExp(r'^[0-9A-Fa-f-]{20,}$').hasMatch(udid)) continue;
    if (t.toLowerCase().contains('network')) continue;
    if (!out.contains(udid)) out.add(udid);
  }
  return out;
}

/// Parses top-level `Key: Value` lines of `ideviceinfo` output.
Map<String, String> parseDeviceInfo(String stdout) {
  final out = <String, String>{};
  for (final line in stdout.split('\n')) {
    if (line.startsWith(' ') || line.startsWith('\t')) continue;
    final idx = line.indexOf(': ');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(key)) continue;
    out[key] = line.substring(idx + 2).trim();
  }
  return out;
}

/// Maps libimobiledevice error output to an [IPhoneErrorKind].
IPhoneErrorKind classifyToolError(String output) {
  final o = output.toLowerCase();
  final codeMatch = RegExp(r'\((-\d+)\)|error code:? (-?\d+)|error (-\d+)')
      .firstMatch(o);
  final code = codeMatch == null
      ? null
      : int.tryParse(
          codeMatch.group(1) ?? codeMatch.group(2) ?? codeMatch.group(3)!,
        );

  if (o.contains('no device found') ||
      o.contains('device not found') ||
      o.contains('no device with udid')) {
    return IPhoneErrorKind.noDevice;
  }
  if (code == -18 || o.contains('user denied pairing')) {
    return IPhoneErrorKind.pairingDenied;
  }
  if (code == -17 ||
      code == -35 ||
      o.contains('password protected') ||
      o.contains('passcode') ||
      o.contains('escrow locked')) {
    return IPhoneErrorKind.deviceLocked;
  }
  if (code == -19 ||
      code == -20 ||
      code == -21 ||
      code == -29 ||
      code == -31 ||
      o.contains('pairing dialog response pending') ||
      o.contains('invalid host') ||
      o.contains('missing host') ||
      o.contains('pair record') ||
      o.contains('not paired')) {
    return IPhoneErrorKind.trustRequired;
  }
  if (o.contains('could not start service') || o.contains('crashreport')) {
    return IPhoneErrorKind.crashReportsUnavailable;
  }
  return IPhoneErrorKind.communication;
}

String _messageFor(IPhoneErrorKind kind) => switch (kind) {
  IPhoneErrorKind.trustRequired =>
    'Unlock your iPhone and tap “Trust” to allow this Mac to read diagnostics.',
  IPhoneErrorKind.pairingDenied => 'Pairing was declined on the iPhone. Unplug and reconnect it, then tap “Trust”.',
  IPhoneErrorKind.deviceLocked =>
    'Unlock your iPhone with its passcode, then try again.',
  IPhoneErrorKind.timeout =>
    'The iPhone did not answer in time. Keep it unlocked and try again.',
  IPhoneErrorKind.noDevice => 'Connect an iPhone using USB.',
  IPhoneErrorKind.toolsUnavailable =>
    'The libimobiledevice tools are not installed.',
  IPhoneErrorKind.crashReportsUnavailable =>
    'The iPhone refused to share its crash reports.',
  IPhoneErrorKind.communication =>
    'The iPhone is connected but did not respond correctly.',
};
