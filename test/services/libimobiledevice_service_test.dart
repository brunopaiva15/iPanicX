import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanix/models/device_status.dart';
import 'package:ipanix/models/diagnostic_file.dart';
import 'package:ipanix/services/command_runner.dart';
import 'package:ipanix/services/iphone_service.dart';
import 'package:ipanix/services/libimobiledevice_service.dart';
import 'package:ipanix/services/tool_locator.dart';
import 'package:ipanix/services/usb_probe.dart';

import '../helpers.dart';

const _udid = '00008120-001A2B3C4D5E6F7A';

const _info = '''ActivationState: Activated
BuildVersion: 23A355
DeviceName: Bruno's iPhone
HardwareModel: D73AP
ProductType: iPhone15,2
ProductVersion: 26.0.1
ProtocolVersion: 2
SupportedDeviceFamilies:
 0: 1
UniqueDeviceID: 00008120-001A2B3C4D5E6F7A
''';

/// Scripted replacement for the libimobiledevice executables.
class FakeRunner implements CommandRunner {
  FakeRunner(this.handler);

  final Future<CommandResult> Function(
    String tool,
    List<String> args,
    void Function(String line)? onLine,
  )
  handler;
  final calls = <String>[];

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 15),
    void Function(String line)? onStdoutLine,
  }) {
    final tool = executable.split('/').last;
    calls.add('$tool ${arguments.join(' ')}');
    return handler(tool, arguments, onStdoutLine);
  }
}

/// Host USB checks with fixed answers.
class FakeProbe extends UsbProbe {
  FakeProbe({this.mux = true, this.presence})
    : super(isWindows: true, isMacOS: false, environment: const {});

  final bool? mux;
  final UsbPresence? presence;
  int presenceQueries = 0;

  @override
  Future<bool?> usbmuxReachable() async => mux;

  @override
  Future<UsbPresence?> appleDeviceOnUsb() async {
    presenceQueries++;
    return presence;
  }
}

void main() {
  late Directory tmp;
  late Directory tools;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ipanix_test_');
    tools = Directory('${tmp.path}/bin')..createSync();
    for (final t in [
      'idevice_id',
      'ideviceinfo',
      'idevicecrashreport',
      'idevicepair',
    ]) {
      File('${tools.path}/$t').writeAsStringSync('');
    }
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  LibimobiledeviceService service(
    FakeRunner runner, {
    bool withTools = true,
    UsbProbe? probe,
  }) => LibimobiledeviceService(
    runner: runner,
    probe: probe ?? FakeProbe(),
    locator: ToolLocator(
      environment: {
        'IPANIX_TOOLS_DIR': withTools ? tools.path : '${tmp.path}/none',
        'PATH': '',
      },
      resolvedExecutable: '${tmp.path}/App.app/Contents/MacOS/app',
    ),
    workRoot: Directory('${tmp.path}/work'),
    pollInterval: const Duration(hours: 1),
  );

  group('output parsing', () {
    test('parseDeviceList handles suffixes, blanks and duplicates', () {
      expect(
        parseDeviceList(
          '$_udid (USB)\n\n$_udid\n0123456789abcdef0123456789abcdef01234567\n',
        ),
        [_udid, '0123456789abcdef0123456789abcdef01234567'],
      );
      expect(parseDeviceList(''), isEmpty);
      expect(parseDeviceList('$_udid (Network)'), isEmpty);
    });

    test('parseDeviceInfo keeps top-level keys only', () {
      final v = parseDeviceInfo(_info);
      expect(v['ProductType'], 'iPhone15,2');
      expect(v['DeviceName'], "Bruno's iPhone");
      expect(v.containsKey('0'), isFalse);
    });

    test('classifyToolError maps lockdown errors', () {
      expect(
        classifyToolError(
          'ERROR: Could not connect to lockdownd: Pairing dialog response pending (-19)',
        ),
        IPhoneErrorKind.trustRequired,
      );
      expect(
        classifyToolError(
          'ERROR: Could not connect to lockdownd, error code -19',
        ),
        IPhoneErrorKind.trustRequired,
      );
      expect(
        classifyToolError(
          'ERROR: Could not connect to lockdownd: Invalid HostID (-21)',
        ),
        IPhoneErrorKind.trustRequired,
      );
      expect(
        classifyToolError(
          'ERROR: Could not connect to lockdownd: Password protected (-17)',
        ),
        IPhoneErrorKind.deviceLocked,
      );
      expect(
        classifyToolError(
          'ERROR: Could not connect to lockdownd: User denied pairing (-18)',
        ),
        IPhoneErrorKind.pairingDenied,
      );
      expect(
        classifyToolError('ERROR: No device found with udid $_udid.'),
        IPhoneErrorKind.noDevice,
      );
      expect(
        classifyToolError(
          'ERROR: Could not start service com.apple.crashreportmover.',
        ),
        IPhoneErrorKind.crashReportsUnavailable,
      );
      expect(
        classifyToolError(
          'ERROR: Could not connect to lockdownd: SSL error (-5)',
        ),
        IPhoneErrorKind.communication,
      );
    });
  });

  group('device detection', () {
    test('connected device with info', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => switch (tool) {
            'idevice_id' => const CommandResult(0, '$_udid\n', ''),
            'ideviceinfo' => const CommandResult(0, _info, ''),
            _ => const CommandResult(1, '', 'unexpected'),
          },
        ),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.connected);
      final d = (await s.getCurrentDevice())!;
      expect(d.productType, 'iPhone15,2');
      expect(d.modelName, 'iPhone 14 Pro');
      expect(d.productVersion, '26.0.1');
      expect(d.buildVersion, '23A355');
      expect(d.maskedUdid, isNot(contains('1A2B3C4D5E')));
      s.dispose();
    });

    test('no device', () async {
      final s = service(
        FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.noDevice);
      expect(await s.getCurrentDevice(), isNull);
      s.dispose();
    });

    test(
      'nothing listed and nothing on USB: no device, with details',
      () async {
        final probe = FakeProbe(presence: const UsbPresence(present: false));
        final s = service(
          FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
          probe: probe,
        );
        await s.start();
        expect(s.currentStatus.state, DeviceConnectionState.noDevice);
        expect(s.currentStatus.technicalDetails, contains('no Apple device'));
        expect(s.currentStatus.technicalDetails, contains('127.0.0.1:27015'));
        s.dispose();
      },
    );

    test('iPhone on USB but not listed: not recognized', () async {
      final s = service(
        FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
        probe: FakeProbe(
          presence: const UsbPresence(
            present: true,
            driverProblem: true,
            details: '28|Apple Mobile Device USB Composite Device|USB\\X',
          ),
        ),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.notRecognized);
      expect(s.currentStatus.reason, StatusReason.driverProblem);
      expect(s.currentStatus.technicalDetails, contains('driver error'));
      s.dispose();
    });

    test('usbmuxd unreachable: communication error', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => const CommandResult(
            255,
            '',
            'ERROR: Unable to retrieve device list!',
          ),
        ),
        probe: FakeProbe(mux: false),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.communicationError);
      expect(s.currentStatus.reason, StatusReason.usbServiceUnavailable);
      expect(
        s.currentStatus.technicalDetails,
        contains('Unable to retrieve device list'),
      );
      s.dispose();
    });

    test('OS USB query is throttled between polls', () async {
      final probe = FakeProbe(presence: const UsbPresence(present: false));
      final s = service(
        FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
        probe: probe,
      );
      await s.start();
      await s.getCurrentDevice();
      expect(probe.presenceQueries, 1);
      await s.refresh(); // explicit retry: queries again
      expect(probe.presenceQueries, 2);
      s.dispose();
    });

    test('several devices: first one selected, count reported', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => switch (tool) {
            'idevice_id' => const CommandResult(
              0,
              '$_udid\n00008110-000000000000001E\n',
              '',
            ),
            _ => const CommandResult(0, _info, ''),
          },
        ),
      );
      await s.start();
      expect(s.currentStatus.isConnected, isTrue);
      expect(s.currentStatus.udid, _udid);
      expect(s.currentStatus.hasMultipleDevices, isTrue);
      s.dispose();
    });

    test('trust required keeps partial unpaired info', () async {
      final s = service(
        FakeRunner((tool, args, _) async {
          if (tool == 'idevice_id') {
            return const CommandResult(0, '$_udid\n', '');
          }
          if (args.contains('-s')) {
            return const CommandResult(
              0,
              'ProductType: iPhone15,2\nProductVersion: 26.0.1\n',
              '',
            );
          }
          return const CommandResult(
            255,
            '',
            'ERROR: Could not connect to lockdownd: Pairing dialog response pending (-19)',
          );
        }),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.trustRequired);
      expect(s.currentStatus.device?.productType, 'iPhone15,2');
      expect(s.currentStatus.device?.isPaired, isFalse);
      expect(s.currentStatus.technicalDetails, contains('-19'));
      s.dispose();
    });

    test('locked device', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => tool == 'idevice_id'
              ? const CommandResult(0, '$_udid\n', '')
              : const CommandResult(
                  255,
                  '',
                  'ERROR: Could not connect to lockdownd: Password protected (-17)',
                ),
        ),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.locked);
      s.dispose();
    });

    test('timeout is a communication error', () async {
      final s = service(
        FakeRunner((tool, args, _) async {
          if (tool == 'idevice_id') {
            return const CommandResult(0, '$_udid\n', '');
          }
          throw const CommandTimeoutException(
            'ideviceinfo',
            Duration(seconds: 12),
            '',
          );
        }),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.communicationError);
      s.dispose();
    });

    test('missing tools', () async {
      final s = service(
        FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
        withTools: false,
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.toolsUnavailable);
      expect(s.currentStatus.technicalDetails, contains('idevice_id'));
      s.dispose();
    });

    test('command that cannot be launched', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => throw const CommandNotFoundException(
            'idevice_id',
            'No such file',
          ),
        ),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.toolsUnavailable);
      s.dispose();
    });
  });

  group('crash reports', () {
    test(
      'copies with -k (keep on device) and lists files newest first',
      () async {
        late FakeRunner runner;
        runner = FakeRunner((tool, args, onLine) async {
          switch (tool) {
            case 'idevice_id':
              return const CommandResult(0, '$_udid\n', '');
            case 'ideviceinfo':
              return const CommandResult(0, _info, '');
            case 'idevicecrashreport':
              final dir = args.last;
              File(
                '$dir/panic-full-2026-10-04-174233.ips',
              ).writeAsStringSync(loadSample(smcSample));
              Directory('$dir/Retired').createSync();
              File(
                '$dir/Retired/panic-full-2026-09-28-091502.ips',
              ).writeAsStringSync(loadSample(unknownSample));
              File(
                '$dir/JetsamEvent-2026-10-02-120144.ips',
              ).writeAsStringSync('{}');
              onLine?.call('Copy: panic-full-2026-10-04-174233.ips');
              onLine?.call('Copy: Retired/panic-full-2026-09-28-091502.ips');
              onLine?.call('Copy: JetsamEvent-2026-10-02-120144.ips');
              return const CommandResult(0, 'Done.\n', '');
          }
          return const CommandResult(1, '', '');
        });
        final s = service(runner);
        await s.start();
        final progress = <int>[];
        final files = await s.getCrashReports(
          onProgress: (n, _) => progress.add(n),
        );

        expect(
          runner.calls.last,
          startsWith('idevicecrashreport -u $_udid -k '),
        );
        expect(progress, [1, 2, 3]);
        expect(files, hasLength(3));
        expect(files.first.name, 'panic-full-2026-10-04-174233.ips');
        expect(
          files.where((f) => f.type == DiagnosticFileType.panicFull),
          hasLength(2),
        );
        expect(
          files.any(
            (f) => f.relativePath == 'Retired/panic-full-2026-09-28-091502.ips',
          ),
          isTrue,
        );
        expect(
          await s.readCrashReport(files.first),
          contains('SMC BSC failure'),
        );
        s.dispose();
      },
    );

    test('failure without files throws a user-facing error', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => switch (tool) {
            'idevice_id' => const CommandResult(0, '$_udid\n', ''),
            'ideviceinfo' => const CommandResult(0, _info, ''),
            _ => const CommandResult(
              255,
              '',
              'ERROR: Could not start service com.apple.crashreportcopymobile.',
            ),
          },
        ),
      );
      await s.start();
      await expectLater(
        s.getCrashReports(),
        throwsA(
          isA<IPhoneServiceException>()
              .having(
                (e) => e.kind,
                'kind',
                IPhoneErrorKind.crashReportsUnavailable,
              )
              .having(
                (e) => e.technicalDetails,
                'details',
                contains('crashreportcopymobile'),
              ),
        ),
      );
      s.dispose();
    });

    test('refuses to scan when no device is connected', () async {
      final s = service(
        FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
      );
      await s.start();
      await expectLater(
        s.getCrashReports(),
        throwsA(isA<IPhoneServiceException>()),
      );
      s.dispose();
    });
  });

  group('USB probe parsing', () {
    test('Windows PnP lines', () {
      final ok = parseWindowsPnp(
        '0|Apple Mobile Device USB Composite Device|USB\\VID_05AC&PID_12A8\\0000\r\n'
        '0|Apple iPhone|USB\\VID_05AC&PID_12A8&MI_00\\6&1\r\n',
      );
      expect(ok.present, isTrue);
      expect(ok.driverProblem, isFalse);
      final bad = parseWindowsPnp(
        '28|Apple iPhone|USB\\VID_05AC&PID_12A8\\0\n',
      );
      expect(bad.present, isTrue);
      expect(bad.driverProblem, isTrue);
      expect(parseWindowsPnp('').present, isFalse);
    });

    test('macOS ioreg', () {
      final p = parseMacIoreg(
        '  | +-o iPhone@01100000  <class IOUSBHostDevice>\n'
        '  |     "USB Product Name" = "iPhone"\n'
        '  |     "USB Product Name" = "Magic Keyboard"\n',
      );
      expect(p.present, isTrue);
      expect(p.details, 'iPhone');
      expect(parseMacIoreg('"USB Product Name" = "Mouse"').present, isFalse);
    });

    test('Windows query is valid PowerShell text', () {
      expect(UsbProbe.windowsQuery, contains(r"'USB\\VID_05AC&PID_12%'"));
      expect(
        UsbProbe(isWindows: true, environment: const {}).usbmuxAddress,
        '127.0.0.1:27015',
      );
      expect(
        UsbProbe(isWindows: false, environment: const {}).usbmuxAddress,
        '/var/run/usbmuxd',
      );
    });
  });

  test('DiagnosticFile parses dates and types from names', () {
    expect(
      DiagnosticFile.classify('panic-full-2026-10-04-174233.0002.ips'),
      DiagnosticFileType.panicFull,
    );
    expect(
      DiagnosticFile.classify('panic-base-2026-10-04-174233.ips'),
      DiagnosticFileType.panicBase,
    );
    expect(
      DiagnosticFile.classify('ResetCounter-2026-10-04-174233.ips'),
      DiagnosticFileType.resetCounter,
    );
    expect(
      DiagnosticFile.classify('stacks-2026-10-04-174233.ips'),
      DiagnosticFileType.stacks,
    );
    expect(
      DiagnosticFile.dateFromFileName('panic-full-2026-10-04-174233.0002.ips'),
      DateTime(2026, 10, 4, 17, 42, 33),
    );
    expect(DiagnosticFile.dateFromFileName('Analytics.ips'), isNull);
  });
}
