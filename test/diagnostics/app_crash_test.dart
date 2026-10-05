import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/diagnostics/app_crash.dart';
import 'package:ipanicx/models/diagnostic_file.dart';

DiagnosticFile _file(String name) =>
    DiagnosticFile.fromPath(path: '/tmp/$name', rootDirectory: '/tmp');

AppCrash _crash(
  String app,
  CrashCause cause, {
  bool apple = false,
  DateTime? date,
}) => AppCrash(
  file: _file('$app-2026-10-04-120000.ips'),
  app: app,
  cause: cause,
  firstParty: apple,
  date: date ?? DateTime(2026, 10, 4, 12),
);

String _ips(Map<String, Object?> header, Map<String, Object?> body) =>
    '${jsonEncode(header)}\n${jsonEncode(body)}';

void main() {
  test('real iOS 17 report (309): memory error', () {
    final c = AppCrashParser.parse(
      _file('Runner-2023-10-20-131018.ips'),
      File('test/fixtures/real/app-crash-309.ips').readAsStringSync(),
    );
    expect(c.app, 'Runner');
    expect(c.bundleId, 'com.example.objectboxCrash');
    expect(c.version, '1.0.0');
    expect(c.exceptionType, 'EXC_BAD_ACCESS');
    expect(c.signal, 'SIGSEGV');
    expect(c.subtype, contains('KERN_INVALID_ADDRESS'));
    expect(c.cause, CrashCause.memoryAccess);
    expect(c.firstParty, isFalse);
    expect(c.date, isNotNull);
  });

  test('real legacy text report (109): abort', () {
    final c = AppCrashParser.parse(
      _file('itunescloudd-2021-10-22-001453.ips'),
      File('test/fixtures/real/app-crash-legacy-109.ips').readAsStringSync(),
    );
    expect(c.app, 'itunescloudd');
    expect(c.firstParty, isTrue);
    expect(c.exceptionType, 'EXC_CRASH');
    expect(c.signal, 'SIGABRT');
    expect(c.terminationReason, 'abort() called');
    expect(c.cause, CrashCause.abort);
  });

  test('termination codes: watchdog, thermal, file lock', () {
    AppCrash withCode(Object code) => AppCrashParser.parse(
      _file('Safari-2026-10-04-120000.ips'),
      _ips(
        {'app_name': 'Safari', 'bug_type': '309'},
        {
          'exception': {'type': 'EXC_CRASH', 'signal': 'SIGKILL'},
          'termination': {
            'namespace': 'FRONTBOARD',
            'code': code,
            'indicator': 'scene-update watchdog transgression',
          },
        },
      ),
    );
    final w = withCode(2343432205);
    expect(w.terminationCode, '0x8badf00d');
    expect(w.cause, CrashCause.watchdog);
    expect(w.terminationReason, 'scene-update watchdog transgression');
    expect(w.technical, 'EXC_CRASH (SIGKILL) · FRONTBOARD 0x8badf00d');
    expect(withCode('0xc00010ff').cause, CrashCause.thermal);
    expect(withCode('0xDEAD10CC').cause, CrashCause.fileLock);
    expect(withCode(9).cause, CrashCause.killed);
  });

  test('exception types without termination code', () {
    CrashCause cause(String type, [String? signal, String? subtype]) =>
        AppCrashParser.classify(type, signal, subtype, null, null);
    expect(cause('EXC_BREAKPOINT', 'SIGTRAP'), CrashCause.swiftError);
    expect(cause('EXC_RESOURCE', null, 'MEMORY'), CrashCause.memoryLimit);
    expect(cause('EXC_RESOURCE', null, 'CPU'), CrashCause.cpuLimit);
    expect(cause('EXC_GUARD'), CrashCause.guard);
    expect(cause('EXC_CRASH', 'SIGABRT'), CrashCause.abort);
    expect(cause('EXC_WEIRD'), CrashCause.other);
  });

  test('crashed frame from the faulting thread', () {
    final c = AppCrashParser.parse(
      _file('App-2026-10-04-120000.ips'),
      _ips(
        {'app_name': 'App'},
        {
          'exception': {'type': 'EXC_BAD_ACCESS', 'signal': 'SIGBUS'},
          'faultingThread': 1,
          'threads': [
            {'frames': []},
            {
              'frames': [
                {'imageIndex': 1, 'symbol': 'objc_msgSend'},
              ],
            },
          ],
          'usedImages': [
            {'name': 'App'},
            {'name': 'libobjc.A.dylib'},
          ],
        },
      ),
    );
    expect(c.crashedIn, 'libobjc.A.dylib  objc_msgSend');
  });

  test('broken report: name from the file, never throws', () {
    final c = AppCrashParser.parse(
      _file('WhatsApp-2026-10-04-120000.ips'),
      'not json at all',
    );
    expect(c.app, 'WhatsApp');
    expect(c.cause, CrashCause.other);
  });

  group('patterns', () {
    test('one app dominates', () {
      final s = AppCrashSummary([
        for (var i = 0; i < 8; i++)
          _crash('Instagram', CrashCause.memoryAccess),
        _crash('Maps', CrashCause.abort, apple: true),
        _crash('Safari', CrashCause.watchdog, apple: true),
      ]);
      expect(s.pattern, CrashPattern.oneApp);
      expect(s.apps.first.app, 'Instagram');
      expect(s.apps.first.mainCause, CrashCause.memoryAccess);
      expect(s.causes[CrashCause.memoryAccess], 8);
    });

    test('memory errors across many apps, incl. Apple ones', () {
      final s = AppCrashSummary([
        for (final a in ['A', 'B', 'Safari', 'Mail', 'C'])
          for (var i = 0; i < 2; i++)
            _crash(
              a,
              CrashCause.memoryAccess,
              apple: a == 'Safari' || a == 'Mail',
            ),
      ]);
      expect(s.pattern, CrashPattern.systemWide);
    });

    test('thermal wins, then spread', () {
      expect(
        AppCrashSummary([
          _crash('A', CrashCause.thermal),
          _crash('B', CrashCause.abort),
        ]).pattern,
        CrashPattern.thermal,
      );
      expect(
        AppCrashSummary([
          _crash('A', CrashCause.abort),
          _crash('B', CrashCause.abort),
          _crash('C', CrashCause.watchdog),
        ]).pattern,
        CrashPattern.spread,
      );
      expect(AppCrashSummary(const []).pattern, isNull);
    });

    test('per-day counts, oldest first', () {
      final now = DateTime(2026, 10, 5, 10);
      final s = AppCrashSummary([
        _crash('A', CrashCause.abort, date: DateTime(2026, 10, 5, 8)),
        _crash('A', CrashCause.abort, date: DateTime(2026, 10, 5, 9)),
        _crash('A', CrashCause.abort, date: DateTime(2026, 10, 3, 9)),
        _crash('A', CrashCause.abort, date: DateTime(2026, 9, 1)),
      ]);
      expect(s.perDay(now, 7), [0, 0, 0, 0, 1, 0, 2]);
    });
  });
}
