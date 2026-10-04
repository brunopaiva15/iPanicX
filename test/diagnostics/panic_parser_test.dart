import 'package:flutter_test/flutter_test.dart';
import 'package:ipanix/diagnostics/panic_parser.dart';

import '../helpers.dart';

void main() {
  const parser = PanicParser();

  group('valid panic-full (header line + JSON body)', () {
    final report = parser.parse(loadSample(smcSample));

    test('extracts device and OS fields', () {
      expect(report.product, 'iPhone15,2');
      expect(report.osVersion, '26.0.1');
      expect(report.build, '23A355');
      expect(report.bugType, '210');
      expect(report.isFullPanic, isTrue);
      expect(report.socId, '8120');
      expect(report.incident, '8C1F2A44-7B1E-4D59-9E7A-3F7C1B2D9A10');
      expect(report.kernelVersion, startsWith('Darwin Kernel Version 25.0.0'));
      expect(report.panicFlags, '0x2');
    });

    test('parses timestamp with timezone offset', () {
      expect(report.timestamp, isNotNull);
      expect(report.timestamp!.toUtc(), DateTime.utc(2026, 10, 4, 15, 42, 33));
    });

    test('extracts panic string, headline and initiator', () {
      expect(report.hasPanicString, isTrue);
      expect(report.panicString, contains('SMC BSC failure'));
      expect(report.headline, startsWith('SMC PANIC - ASSERTION FAILED'));
      expect(report.panicInitiator, 'SMC');
      expect(report.panickedProcess, 'kernel_task');
    });

    test('converts decimal sensor array to hex mask', () {
      expect(report.sensorMask, 1310720);
      expect(report.sensorMaskHex, '0x140000');
    });

    test('extracts SMC sensor keys from the panic line only', () {
      expect(report.sensorKeys, containsAll(['TAOP', 'TAOJ']));
      expect(report.sensorKeys, isNot(contains('UUID')));
      expect(report.sensorKeys, isNot(contains('SMC')));
    });

    test('has no parse warnings', () {
      expect(report.parseWarnings, isEmpty);
    });
  });

  test('missing panicString does not throw and reports a warning', () {
    const content =
        '{"bug_type":"210","timestamp":"2026-10-01 10:00:00.00 +0000",'
        '"os_version":"iPhone OS 26.0 (23A341)"}\n'
        '{"product":"iPhone15,2","build":"iPhone OS 26.0 (23A341)"}';
    final report = parser.parse(content);
    expect(report.hasPanicString, isFalse);
    expect(report.panicString, isNull);
    expect(report.product, 'iPhone15,2');
    expect(report.osVersion, '26.0');
    expect(report.sensorMask, isNull);
    expect(report.headline, isNull);
    expect(report.parseWarnings, contains('No panic string found.'));
  });

  test('sensor array in decimal', () {
    final report = parser.parse(
      '{"bug_type":"210"}\n{"product":"iPhone15,2","panicString":'
      '"panic(cpu 1 caller 0xfffffff0): SMC PANIC - SMC BSC failure sensor array: 1310720"}',
    );
    expect(report.sensorMask, 0x140000);
  });

  test('sensor mask in hexadecimal', () {
    final report = parser.parse(
      '{"bug_type":"210"}\n{"product":"iPhone15,2","panicString":'
      '"panic(cpu 1 caller 0xfffffff0): SMC PANIC - SMC BSC failure, sensor mask = 0x140000"}',
    );
    expect(report.sensorMask, 1310720);
    expect(report.sensorMaskHex, '0x140000');
  });

  test('sensor mask from a dedicated JSON key', () {
    final report = parser.parse(
      '{"product":"iPhone15,2","sensorMask":"0x140000","panicString":"panic(cpu 0 caller 0x1): SMC PANIC"}',
    );
    expect(report.sensorMask, 0x140000);
  });

  test('partially invalid JSON falls back to key extraction', () {
    // Body is truncated in the middle of the panic string (no closing quote).
    const content =
        '{"bug_type":"210","timestamp":"2026-10-04 17:42:33.00 +0200",'
        '"os_version":"iPhone OS 26.0.1 (23A355)"}\n'
        '{\n  "build" : "iPhone OS 26.0.1 (23A355)",\n  "product" : "iPhone15,2",\n'
        '  "socId" : "8120",\n'
        '  "panicString" : "panic(cpu 0 caller 0xfffffff02b3c1d8c): SMC PANIC - '
        'ASSERTION FAILED: SMC BSC failure: sensor array 1310720 (TAOP TAOJ)\\nRTKit: RTKit-2836';
    final report = parser.parse(content);
    expect(report.product, 'iPhone15,2');
    expect(report.socId, '8120');
    expect(report.osVersion, '26.0.1');
    expect(report.panicString, contains('SMC BSC failure'));
    expect(report.sensorMask, 1310720);
    expect(report.sensorKeys, containsAll(['TAOP', 'TAOJ']));
    expect(report.parseWarnings, isNotEmpty);
  });

  test('JSON followed by free text', () {
    final content =
        '${loadSample(smcSample)}\n--- extra notes appended by a tool ---\n';
    final report = parser.parse(content);
    expect(report.product, 'iPhone15,2');
    expect(report.sensorMask, 1310720);
  });

  test('single JSON document', () {
    final report = parser.parse(
      '{"bug_type":"210","product":"iPhone14,7","build":"iPhone OS 18.2 (22C152)",'
      '"panicString":"panic(cpu 3 caller 0xfffffff051260638): \\"LLC Bus error\\""}',
    );
    expect(report.product, 'iPhone14,7');
    expect(report.osVersion, '18.2');
    expect(report.build, '22C152');
    expect(report.headline, '"LLC Bus error"');
  });

  test('legacy plain-text panic report', () {
    const content =
        'panic(cpu 0 caller 0xfffffff007000000): "userspace watchdog '
        'timeout: no successful checkins from thermalmonitord"\n'
        'Missing sensor(s): TG0B mic1\n'
        'Debugger message: panic\n'
        'Panic flags: 0x802\n'
        'OS version: iPhone OS 17.5 (21F79)\n'
        'Kernel version: Darwin Kernel Version 23.5.0: RELEASE_ARM64_T8120\n'
        'Hardware model: iPhone15,2\n'
        '\n'
        'Kernel Extensions in backtrace:\n'
        '   com.apple.driver.AppleSMC(1.0)[BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF]@0xfffffff008000000->0xfffffff00800ffff\n'
        '      dependency: com.apple.iokit.IOReportFamily(47)[653A540C]@0x1->0x2\n'
        '\n'
        'loaded kexts:\n'
        'com.apple.driver.AppleNANDConfigAccess 1\n';
    final report = parser.parse(content);
    expect(report.product, 'iPhone15,2');
    expect(report.osVersion, '17.5');
    expect(report.build, '21F79');
    expect(report.panicFlags, '0x802');
    expect(report.kernelVersion, contains('23.5.0'));
    expect(report.panicString, contains('thermalmonitord'));
    expect(report.missingSensors, ['TG0B', 'mic1']);
    expect(report.backtraceKexts, ['com.apple.driver.AppleSMC']);
    expect(report.panicInitiator, 'watchdog');
  });

  test('non-panic bug_type is flagged', () {
    final report = parser.parse(
      loadSample('JetsamEvent-2026-10-02-120144.ips'),
    );
    expect(report.bugType, '298');
    expect(report.isFullPanic, isFalse);
    expect(report.parseWarnings.join(), contains('not a full kernel panic'));
  });

  test('garbage input never throws', () {
    for (final input in [
      '',
      '{',
      '}}}',
      'not a panic',
      '{"panicString": 12}',
      '﻿{"a":1}',
    ]) {
      expect(() => parser.parse(input), returnsNormally, reason: input);
    }
  });
}
