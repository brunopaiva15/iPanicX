import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/models/device_status.dart';
import 'package:ipanicx/models/diagnostic_file.dart';
import 'package:ipanicx/services/command_runner.dart';
import 'package:ipanicx/services/iphone_service.dart';
import 'package:ipanicx/services/libimobiledevice_service.dart';
import 'package:ipanicx/services/tool_locator.dart';
import 'package:ipanicx/services/usb_probe.dart';

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
    Future<void>? cancel,
  }) {
    final tool = executable.split('/').last;
    calls.add('$tool ${arguments.join(' ')}');
    return handler(tool, arguments, onStdoutLine);
  }

  /// Lines served by [stream] (e.g. a scripted `idevicesyslog`).
  List<String> streamLines = const [];

  @override
  Stream<String> stream(String executable, List<String> arguments) {
    calls.add('${executable.split('/').last} ${arguments.join(' ')}');
    return Stream.fromIterable(streamLines);
  }
}

/// Host USB checks with fixed answers.
class FakeProbe extends UsbProbe {
  FakeProbe({this.mux = true, this.presence, this.support})
    : super(isWindows: true, isMacOS: false, environment: const {});

  final bool? mux;
  final UsbPresence? presence;
  final AppleSupport? support;
  int presenceQueries = 0;

  @override
  Future<AppleSupport?> appleSupport() async => support;

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
    tmp = Directory.systemTemp.createTempSync('ipanicx_test_');
    tools = Directory('${tmp.path}/bin')..createSync();
    for (final t in [
      'idevice_id',
      'ideviceinfo',
      'idevicecrashreport',
      'idevicepair',
      'idevicediagnostics',
      'idevicesyslog',
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
        'IPANICX_TOOLS_DIR': withTools ? tools.path : '${tmp.path}/none',
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

    test('usbmuxd unreachable: reported without running idevice_id', () async {
      final runner = FakeRunner(
        (tool, args, _) async => const CommandResult(0, '', ''),
      );
      final s = service(runner, probe: FakeProbe(mux: false));
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.communicationError);
      expect(s.currentStatus.reason, StatusReason.usbServiceUnavailable);
      expect(s.currentStatus.technicalDetails, contains('not reachable'));
      expect(runner.calls, isEmpty);
      s.dispose();
    });

    test('Windows without Apple Devices / iTunes: install warning', () async {
      final s = service(
        FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
        probe: FakeProbe(
          mux: false,
          support: const AppleSupport(installed: false, details: 'none'),
        ),
      );
      await s.start();
      expect(s.currentStatus.reason, StatusReason.appleDevicesMissing);
      s.dispose();
    });

    test('Apple Devices installed but service down: stopped', () async {
      final s = service(
        FakeRunner((tool, args, _) async => const CommandResult(0, '', '')),
        probe: FakeProbe(
          mux: false,
          support: const AppleSupport(installed: true),
        ),
      );
      await s.start();
      expect(s.currentStatus.reason, StatusReason.appleServiceStopped);
      s.dispose();
    });

    test(
      'idevice_id failing for another reason: communication error',
      () async {
        final s = service(
          FakeRunner(
            (tool, args, _) async => const CommandResult(
              255,
              '',
              'ERROR: Unable to retrieve device list!',
            ),
          ),
        );
        await s.start();
        expect(s.currentStatus.state, DeviceConnectionState.communicationError);
        expect(
          s.currentStatus.technicalDetails,
          contains('Unable to retrieve device list'),
        );
        s.dispose();
      },
    );

    test('list timeout keeps partial output and usbmuxd state', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => throw const CommandTimeoutException(
            'idevice_id',
            Duration(seconds: 12),
            'partial',
          ),
        ),
      );
      await s.start();
      expect(s.currentStatus.reason, StatusReason.timeout);
      expect(s.currentStatus.technicalDetails, contains('reachable'));
      expect(s.currentStatus.technicalDetails, contains('partial'));
      s.dispose();
    });

    test('Windows loader failure (missing DLL) means broken tools', () async {
      final s = service(
        FakeRunner(
          (tool, args, _) async => const CommandResult(-1073741515, '', ''),
        ),
      );
      await s.start();
      expect(s.currentStatus.state, DeviceConnectionState.toolsUnavailable);
      expect(s.currentStatus.technicalDetails, contains('DLL'));
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

  group('device facts and live log', () {
    test('reads battery, storage, developer mode, baseband, Wi-Fi', () async {
      final battery = File(
        'test/fixtures/device/apple_smart_battery.plist',
      ).readAsStringSync();
      final runner = FakeRunner((tool, args, _) async {
        if (tool == 'idevice_id') return const CommandResult(0, '$_udid\n', '');
        if (tool == 'idevicediagnostics') {
          return CommandResult(0, battery, '');
        }
        final q = args.contains('-q') ? args[args.indexOf('-q') + 1] : null;
        return switch (q) {
          'com.apple.disk_usage' => const CommandResult(
            0,
            'TotalDataCapacity: 119000000000\nTotalDataAvailable: 7140000000\n',
            '',
          ),
          'com.apple.security.mac.amfi' => const CommandResult(
            0,
            'DeveloperModeStatus: false\n',
            '',
          ),
          'com.apple.mobile.battery' => const CommandResult(
            0,
            'BatteryCurrentCapacity: 72\n',
            '',
          ),
          _ => CommandResult(
            0,
            '$_info'
                'BasebandVersion: 2.00.01\nWiFiAddress: a4:83:e7:12:34:56\n',
            '',
          ),
        };
      });
      final s = service(runner);
      await s.start();
      final f = await s.getDeviceFacts();
      expect(f.battery!.healthPercent, 77);
      expect(f.battery!.cycleCount, 843);
      expect(f.storage!.usedPercent, 94);
      expect(f.developerMode, isFalse);
      expect(f.basebandVersion, '2.00.01');
      expect(f.wifiAddress, 'a4:83:e7:12:34:56');
      expect(
        runner.calls,
        contains('idevicediagnostics -u $_udid ioregentry AppleSmartBattery'),
      );
      expect(
        runner.calls,
        contains('idevicediagnostics -u $_udid diagnostics GasGauge'),
      );
      // AppleSmartBattery answered with capacities: no charger fallback.
      expect(
        runner.calls.where((c) => c.contains('AppleARMPMUCharger')),
        isEmpty,
      );
      expect(f.raw, contains('GasGauge:'));
      s.dispose();
    });

    test('older iPhone: falls back to AppleARMPMUCharger', () async {
      const charger =
          '<plist><dict><key>IORegistry</key><dict>'
          '<key>MaxCapacity</key><integer>1520</integer>'
          '<key>DesignCapacity</key><integer>1810</integer>'
          '</dict></dict></plist>';
      final runner = FakeRunner((tool, args, _) async {
        if (tool == 'idevice_id') {
          return const CommandResult(0, '$_udid\n', '');
        }
        if (tool == 'idevicediagnostics') {
          return args.contains('AppleARMPMUCharger')
              ? const CommandResult(0, charger, '')
              : const CommandResult(
                  1,
                  'ERROR: Unable to retrieve IORegistry from device.',
                  '',
                );
        }
        return const CommandResult(0, _info, '');
      });
      final s = service(runner);
      await s.start();
      final f = await s.getDeviceFacts();
      expect(f.battery!.healthPercent, 84);
      expect(f.notes.join(), contains('AppleSmartBattery'));
      expect(f.raw, contains('AppleARMPMUCharger:'));
      s.dispose();
    });

    test('missing values stay missing, with notes', () async {
      final s = service(
        FakeRunner((tool, args, _) async {
          if (tool == 'idevice_id') {
            return const CommandResult(0, '$_udid\n', '');
          }
          if (tool == 'ideviceinfo' && args.length == 2) {
            return const CommandResult(0, _info, '');
          }
          return const CommandResult(255, '', 'ERROR: unsupported');
        }),
      );
      await s.start();
      final f = await s.getDeviceFacts();
      expect(f.battery, isNull);
      expect(f.storage, isNull);
      expect(f.developerMode, isNull);
      expect(f.notes, isNotEmpty);
      s.dispose();
    });

    test('syslog strips colours', () async {
      final runner = FakeRunner(
        (tool, args, _) async => tool == 'idevice_id'
            ? const CommandResult(0, '$_udid\n', '')
            : const CommandResult(0, _info, ''),
      )..streamLines = ['\x1B[0;32mkernel\x1B[0m: watchdog timeout'];
      final s = service(runner);
      await s.start();
      expect(await s.syslog().toList(), ['kernel: watchdog timeout']);
      s.dispose();
    });

    test('a cancelled copy is reported as cancelled', () async {
      final s = service(
        FakeRunner((tool, args, _) async {
          if (tool == 'idevice_id') {
            return const CommandResult(0, '$_udid\n', '');
          }
          if (tool == 'idevicecrashreport') {
            throw const CommandCancelledException('idevicecrashreport');
          }
          return const CommandResult(0, _info, '');
        }),
      );
      await s.start();
      await expectLater(
        s.getCrashReports(),
        throwsA(
          isA<IPhoneServiceException>().having(
            (e) => e.kind,
            'kind',
            IPhoneErrorKind.cancelled,
          ),
        ),
      );
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

    test('Apple support query output', () {
      final none = parseAppleSupport('service=|\r\npackages=\r\n')!;
      expect(none.installed, isFalse);
      final store = parseAppleSupport(
        'service=Apple Mobile Device Service|Stopped\npackages=AppleInc.AppleDevices\n',
      )!;
      expect(store.installed, isTrue);
      expect(store.serviceRunning, isFalse);
      final itunes = parseAppleSupport(
        'service=Apple Mobile Device Service|Running\npackages=\n',
      )!;
      expect(itunes.installed, isTrue);
      expect(itunes.serviceRunning, isTrue);
      expect(parseAppleSupport('garbage'), isNull);
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
