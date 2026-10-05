import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/diagnostics/panic_analyzer.dart';
import 'package:ipanicx/diagnostics/panic_parser.dart';
import 'package:ipanicx/models/diagnostic_file.dart';
import 'package:ipanicx/models/diagnostic_result.dart';
import 'package:ipanicx/models/panic_report.dart';

import '../helpers.dart';

/// Excerpts of real reports (see test/fixtures/real/SOURCES.md).
void main() {
  const parser = PanicParser();
  final analyzer = PanicAnalyzer(loadKnowledgeBase());

  PanicReport parse(String name) =>
      parser.parse(File('test/fixtures/real/$name').readAsStringSync());
  DiagnosticResult analyze(String name) => analyzer.analyze(parse(name));

  test('AOP panic (iPhone18,2, iOS 26.3) with JSON panicInitiator', () {
    final r = parse('aop-panic.ips');
    expect(r.product, 'iPhone18,2');
    expect(r.osVersion, '26.3');
    expect(r.build, '23D127');
    expect(r.panicInitiator, 'AOP');
    expect(r.panicFlags, '0x40802');
    expect(r.timestamp!.toUtc(), DateTime.utc(2026, 2, 13, 22, 37, 14));
    final d = analyzer.analyze(r);
    expect(d.matchedRuleId, 'aop_sensorhub_generic');
    expect(d.rawCodes, contains('AOP PANIC'));
  });

  test('AGX GPU panic', () {
    expect(analyze('agx-panic-full.ips').matchedRuleId, 'gpu_agx_generic');
  });

  test('SEP panic', () {
    expect(analyze('sep-panic-full.ips').matchedRuleId, 'sep_panic_generic');
  });

  test('DART (IOMMU) fault on iOS 27', () {
    final r = parse('dart-panic-full.ips');
    expect(r.osVersion, '27.0');
    expect(analyzer.analyze(r).matchedRuleId, 'dart_iommu_generic');
  });

  test('kernel memory faults (data abort, MTE tag check, SPTM)', () {
    for (final f in [
      'ipad-data-abort.ips',
      'mte-tag-fault.ips',
      'panic-base+socd-2023-10-20-130124.000.ips',
    ]) {
      expect(
        analyze(f).matchedRuleId,
        'kernel_memory_fault_generic',
        reason: f,
      );
    }
  });

  test('panic-base+socd: headline skips the CPU-halt preamble', () {
    final r = parse('panic-base+socd-2023-10-20-130124.000.ips');
    expect(r.panicString, startsWith('Attempting to forcibly halt cpu 2'));
    expect(r.headline, startsWith('[SPTM] VIOLATION_ILLEGAL_RETYPE'));
    expect(r.product, 'iPhone14,5');
    expect(
      DiagnosticFile.classify('panic-base+socd-2023-10-20-130124.000.ips'),
      DiagnosticFileType.panicBase,
    );
  });

  test('forced restart (bug_type 151, text in "string")', () {
    final r = parse('forceReset-full-2026-08-08-012443.0002.ips');
    expect(r.bugType, '151');
    expect(r.isForcedReset, isTrue);
    expect(r.headline, 'btn_rst');
    expect(r.parseWarnings, isEmpty);
    final d = analyzer.analyze(r);
    expect(d.matchedRuleId, 'forced_restart_btn_rst');
    expect(d.isHardwareRelated, isFalse);
    expect(
      DiagnosticFile.classify('forceReset-full-2026-08-08-012443.0002.ips'),
      DiagnosticFileType.forceReset,
    );
  });

  test('app crashes and stackshots are not diagnosed as panics', () {
    for (final f in [
      'app-crash-legacy-109.ips',
      'app-crash-309.ips',
      'stacks-288.ips',
    ]) {
      final d = analyze(f);
      expect(d.title, 'Not a Kernel Panic', reason: f);
      expect(d.isKnownSignature, isFalse);
    }
  });
}
