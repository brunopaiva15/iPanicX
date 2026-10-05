import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../models/device_facts.dart';
import '../models/device_status.dart';
import '../models/diagnostic_file.dart';
import '../models/iphone_device.dart';
import 'iphone_service.dart';
import '../app/host_platform.dart';

/// Scenarios the mock can simulate (switchable from the UI in mock mode).
enum MockScenario {
  connected('iPhone connected'),
  multipleDevices('Two iPhones connected'),
  noPanics('Connected, no panic reports'),
  noDevice('No iPhone'),
  notRecognized('iPhone not recognized (driver)'),
  trustRequired('Trust required'),
  locked('Device locked'),
  communicationError('Communication error'),
  usbServiceDown('Apple Mobile Device Service missing'),
  appleDevicesMissing('Apple Devices not installed'),
  appleServiceStopped('Apple service stopped'),
  toolsUnavailable('libimobiledevice unavailable'),
  crashReportError('Crash report copy fails');

  const MockScenario(this.label);
  final String label;
}

typedef SampleLoader = Future<String> Function(String name);

/// Simulated iPhone 14 Pro (iPhone15,2, iOS 26.x) for UI development.
///
/// Enable with `--dart-define=USE_MOCK_DEVICE=true` (or the
/// `USE_MOCK_DEVICE=true` environment variable).
class MockIPhoneService implements IPhoneService {
  MockIPhoneService({
    MockScenario scenario = MockScenario.connected,
    SampleLoader? sampleLoader,
    Directory? workRoot,
    this.latency = const Duration(milliseconds: 400),
  }) : _scenario = scenario, // ignore: prefer_initializing_formals
       _loader =
           sampleLoader ??
           ((name) => rootBundle.loadString('assets/samples/$name')),
       _workRoot =
           workRoot ??
           Directory('${Directory.systemTemp.path}/iPanicX/MockReports');

  static const smcSample = 'panic-full-2026-10-04-174233.ips';
  static const unknownSample = 'panic-full-2026-09-28-091502.ips';
  static const jetsamSample = 'JetsamEvent-2026-10-02-120144.ips';
  static const forceResetSample = 'forceReset-full-2026-08-08-012443.0002.ips';
  static const thermalSample = 'panic-full-2026-10-01-083015.ips';

  static const device = IPhoneDevice(
    udid: '00008120-001A2B3C4D5E6F7A',
    deviceName: 'iPhone 14 Pro',
    productType: 'iPhone15,2',
    productVersion: '26.0.1',
    buildVersion: '23A355',
    hardwareModel: 'D73AP',
  );

  final SampleLoader _loader;
  final Directory _workRoot;
  final Duration latency;
  MockScenario _scenario;
  final _controller = StreamController<DeviceStatus>.broadcast();
  DeviceStatus _status = const DeviceStatus.searching();

  MockScenario get scenario => _scenario;

  @override
  bool get isMock => true;

  @override
  String get backendDescription => 'Mock device (USE_MOCK_DEVICE=true)';

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
  Future<IPhoneDevice?> getCurrentDevice() async =>
      _status.isConnected ? _status.device : null;

  @override
  Future<void> start() async {
    await Future<void>.delayed(latency);
    _emit(_statusFor(_scenario));
  }

  @override
  Future<void> refresh() async => _emit(_statusFor(_scenario));

  @override
  Future<void> requestPairing() async {
    await Future<void>.delayed(latency);
    if (_scenario == MockScenario.trustRequired) {
      setScenario(MockScenario.connected);
    }
  }

  void setScenario(MockScenario scenario) {
    _scenario = scenario;
    _emit(_statusFor(scenario));
  }

  void _emit(DeviceStatus s) {
    _status = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  static DeviceStatus _statusFor(MockScenario s) => switch (s) {
    MockScenario.connected ||
    MockScenario.noPanics ||
    MockScenario.crashReportError => DeviceStatus(
      state: DeviceConnectionState.connected,
      device: device,
      udid: device.udid,
      deviceCount: 1,
    ),
    MockScenario.multipleDevices => DeviceStatus(
      state: DeviceConnectionState.connected,
      device: device,
      udid: device.udid,
      deviceCount: 2,
    ),
    MockScenario.noDevice => const DeviceStatus.noDevice(
      technicalDetails:
          'idevice_id -l: exit 0, no output\n'
          'usbmuxd (127.0.0.1:27015): reachable\n'
          'USB: no Apple device attached',
    ),
    MockScenario.notRecognized => const DeviceStatus(
      state: DeviceConnectionState.notRecognized,
      reason: StatusReason.driverProblem,
      message: 'Windows sees the iPhone, but its Apple driver is not working.',
      technicalDetails:
          'idevice_id -l: exit 0, no output\n'
          'usbmuxd (127.0.0.1:27015): reachable\n'
          'USB: Apple device attached (driver error)\n'
          '28|Apple Mobile Device USB Composite Device|USB\\VID_05AC&PID_12A8\\00008120001A2B3C4D5E6F7A',
    ),
    MockScenario.trustRequired => DeviceStatus(
      state: DeviceConnectionState.trustRequired,
      udid: device.udid,
      device: device.copyWith(isPaired: false),
      deviceCount: 1,
      message:
          'Unlock your iPhone and tap “Trust” to allow this ${HostPlatform.computer} to read diagnostics.',
      technicalDetails:
          'ERROR: Could not connect to lockdownd: Pairing dialog response pending (-19)',
    ),
    MockScenario.locked => DeviceStatus(
      state: DeviceConnectionState.locked,
      udid: device.udid,
      deviceCount: 1,
      message: 'Unlock your iPhone with its passcode, then try again.',
      technicalDetails:
          'ERROR: Could not connect to lockdownd: Password protected (-17)',
    ),
    MockScenario.usbServiceDown => const DeviceStatus(
      state: DeviceConnectionState.communicationError,
      reason: StatusReason.usbServiceUnavailable,
      message: 'Apple Mobile Device Service is not reachable.',
      technicalDetails: 'usbmuxd (127.0.0.1:27015): not reachable',
    ),
    MockScenario.appleDevicesMissing => const DeviceStatus(
      state: DeviceConnectionState.communicationError,
      reason: StatusReason.appleDevicesMissing,
      technicalDetails:
          'usbmuxd (127.0.0.1:27015): not reachable\n'
          'Apple Mobile Device service: not installed\nApple packages: none',
    ),
    MockScenario.appleServiceStopped => const DeviceStatus(
      state: DeviceConnectionState.communicationError,
      reason: StatusReason.appleServiceStopped,
      technicalDetails:
          'usbmuxd (127.0.0.1:27015): not reachable\n'
          'Apple Mobile Device service: Apple Mobile Device Service (Stopped)',
    ),
    MockScenario.communicationError => DeviceStatus(
      state: DeviceConnectionState.communicationError,
      udid: device.udid,
      deviceCount: 1,
      message: 'The iPhone is connected but did not respond correctly.',
      technicalDetails: 'ERROR: Could not connect to lockdownd: SSL error (-5)',
    ),
    MockScenario.toolsUnavailable => const DeviceStatus(
      state: DeviceConnectionState.toolsUnavailable,
      message: 'iPanicX could not find the libimobiledevice tools.',
      technicalDetails: 'Missing: idevice_id, ideviceinfo, idevicecrashreport',
    ),
  };

  @override
  Future<List<DiagnosticFile>> getCrashReports({
    CrashReportProgress? onProgress,
    Future<void>? cancel,
  }) async {
    var cancelled = false;
    cancel?.then((_) => cancelled = true);
    if (!_status.isConnected) {
      throw IPhoneServiceException(
        IPhoneErrorKind.noDevice,
        _status.message ?? 'Connect and unlock your iPhone first.',
      );
    }
    if (_scenario == MockScenario.crashReportError) {
      await Future<void>.delayed(latency);
      throw const IPhoneServiceException(
        IPhoneErrorKind.crashReportsUnavailable,
        'The iPhone refused to share its crash reports.',
        technicalDetails:
            'ERROR: Could not start service com.apple.crashreportcopymobile.',
      );
    }

    final dir = Directory(
      '${_workRoot.path}/${DateTime.now().microsecondsSinceEpoch}',
    );
    await dir.create(recursive: true);
    final smc = await _loader(smcSample);
    final unknown = await _loader(unknownSample);
    final jetsam = await _loader(jetsamSample);
    final forceReset = await _loader(forceResetSample);
    final thermal = await _loader(thermalSample);

    // 12 SMC panics + 2 unknown panics + misc files, spread over 3 weeks.
    final now = DateTime.now();
    var latest = DateTime(now.year, now.month, now.day, 17, 42, 33);
    if (latest.isAfter(now)) latest = now.subtract(const Duration(minutes: 5));
    final entries = <(String, String, DateTime)>[];
    if (_scenario != MockScenario.noPanics) {
      for (var i = 0; i < 12; i++) {
        entries.add((
          'panic-full',
          smc,
          latest.subtract(Duration(hours: 37 * i, minutes: 13 * i)),
        ));
      }
      entries.add((
        'panic-full',
        unknown,
        latest.subtract(const Duration(days: 6, hours: 8)),
      ));
      entries.add((
        'panic-full',
        unknown,
        latest.subtract(const Duration(days: 17, hours: 2)),
      ));
      // Same missing sensor three times: the correlation case.
      for (final days in const [4, 11, 16]) {
        entries.add((
          'panic-full',
          thermal,
          latest.subtract(Duration(days: days, hours: 3)),
        ));
      }
    }
    // App crashes over the last week (headers are enough for the counts).
    const apps = ['Instagram', 'Instagram', 'Safari', 'Instagram', 'Maps'];
    for (var i = 0; i < 9; i++) {
      final app = apps[i % apps.length];
      entries.add((
        app,
        '{"bug_type":"309","app_name":"$app","name":"$app",'
            '"timestamp":"2026-10-04 17:42:33.00 +0200",'
            '"os_version":"iPhone OS 26.0.1 (23A355)"}\n{}\n',
        latest.subtract(Duration(hours: 17 * i + 3)),
      ));
    }
    entries.add((
      'forceReset-full',
      forceReset,
      latest.subtract(const Duration(days: 3, hours: 1)),
    ));
    entries.add((
      'forceReset-full',
      forceReset,
      latest.subtract(const Duration(days: 8, hours: 4)),
    ));
    entries.add((
      'JetsamEvent',
      jetsam,
      latest.subtract(const Duration(days: 2, hours: 5)),
    ));
    entries.add((
      'JetsamEvent',
      jetsam,
      latest.subtract(const Duration(days: 9)),
    ));
    entries.add((
      'ResetCounter',
      '{"bug_type":"115"}\n{"resetCount":3}\n',
      latest.subtract(const Duration(days: 1)),
    ));

    var copied = 0;
    for (final (prefix, template, date) in entries) {
      if (cancelled) {
        throw const IPhoneServiceException(
          IPhoneErrorKind.cancelled,
          'The copy was stopped.',
        );
      }
      // Older reports go to Retired/ like on a real device.
      final retired = now.difference(date).inDays > 10;
      final name = '$prefix-${_fileStamp(date)}.ips';
      final file = File('${dir.path}/${retired ? 'Retired/' : ''}$name');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        _withIncident(_retimestamp(template, date), copied),
      );
      copied++;
      onProgress?.call(copied, name);
      await Future<void>.delayed(latency ~/ 10);
    }
    return listReportFiles(dir);
  }

  @override
  Future<String> readCrashReport(DiagnosticFile file) => readReportFile(file);

  /// iPhone 14 Pro with a worn battery and an almost full storage.
  static const facts = DeviceFacts(
    battery: BatteryInfo(
      chargePercent: 72,
      cycleCount: 843,
      designCapacity: 3200,
      fullChargeCapacity: 2491,
      temperatureC: 31.4,
      isCharging: false,
    ),
    storage: StorageInfo(totalBytes: 128000000000, availableBytes: 7300000000),
    developerMode: false,
    basebandVersion: '2.00.01',
    wifiAddress: 'a4:83:e7:12:34:56',
  );

  @override
  Future<DeviceFacts> getDeviceFacts() async {
    await Future<void>.delayed(latency);
    if (!_status.isConnected) return DeviceFacts.empty;
    return DeviceFacts(
      battery: facts.battery,
      storage: facts.storage,
      developerMode: facts.developerMode,
      basebandVersion: facts.basebandVersion,
      wifiAddress: facts.wifiAddress,
      readAt: DateTime.now(),
    );
  }

  static const _syslogSample = [
    'kernel[0] <Notice>: AppleSMC: battery temperature nominal',
    'SpringBoard[58] <Notice>: Application state changed',
    'thermalmonitord[112] <Error>: Missing sensor(s): TG0B',
    'kernel[0] <Notice>: memorystatus: memory pressure: critical',
    'Instagram[2214] <Error>: Terminating app due to uncaught exception',
    'locationd[88] <Notice>: Location services update',
    'watchdogd[64] <Error>: userspace watchdog timeout: thermalmonitord',
    'kernel[0] <Notice>: AppleUSBHostPort: Lightning accessory attached',
  ];

  @override
  Stream<String> syslog() {
    if (!_status.isConnected) return const Stream.empty();
    var i = 0;
    return Stream.periodic(const Duration(milliseconds: 700), (_) {
      final now = DateTime.now();
      final t = '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
      return 'Oct  5 $t iPhone ${_syslogSample[i++ % _syslogSample.length]}';
    });
  }

  @override
  void dispose() => _controller.close();

  /// Gives every generated copy its own incident id (the scan de-duplicates
  /// reports by incident, like panic-full / panic-base pairs on a device).
  static String _withIncident(String content, int index) {
    final id =
        '00000000-0000-4000-8000-${index.toRadixString(16).padLeft(12, '0').toUpperCase()}';
    return content.replaceAllMapped(
      RegExp(r'("incident(?:_id)?"\s*:\s*")[0-9A-Fa-f-]{36}"'),
      (m) => '${m.group(1)}$id"',
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _fileStamp(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

  /// Rewrites every IPS timestamp in [template] to [date] (local offset).
  static String _retimestamp(String template, DateTime date) {
    final off = date.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final abs = off.abs();
    final tz = '$sign${_two(abs.inHours)}${_two(abs.inMinutes % 60)}';
    final ts =
        '${date.year}-${_two(date.month)}-${_two(date.day)} '
        '${_two(date.hour)}:${_two(date.minute)}:${_two(date.second)}';
    return template.replaceAllMapped(
      RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d+)? [+-]\d{4}'),
      (m) => '$ts${m.group(1) ?? ''} $tz',
    );
  }
}
