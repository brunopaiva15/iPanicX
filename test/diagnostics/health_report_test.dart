import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/diagnostics/correlation.dart';
import 'package:ipanicx/diagnostics/health_report.dart';
import 'package:ipanicx/l10n/strings.dart';
import 'package:ipanicx/models/diagnostic_result.dart';
import 'package:ipanicx/models/scan_result.dart';
import 'package:ipanicx/services/diagnostic_service.dart';
import 'package:ipanicx/services/mock_iphone_service.dart';

import '../helpers.dart';

void main() {
  late Directory tmp;
  late ScanResult scan;
  final kb = loadKnowledgeBase();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipanicx_health_');
    final iphone = MockIPhoneService(
      sampleLoader: sampleLoader,
      workRoot: tmp,
      latency: Duration.zero,
    );
    await iphone.start();
    scan = await DiagnosticService(
      iphone: iphone,
      knowledgeBase: kb,
      useIsolate: false,
    ).scan();
    iphone.dispose();
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('knowledge base maps missing sensors to parts', () {
    expect(kb.sensor('TG0B')!.component, contains('Battery'));
    expect(kb.sensor('tg0b')!.componentIn(AppLang.fr), contains('Batterie'));
    expect(kb.sensor('mic1')!.component, contains('Charging Port Flex'));
    expect(kb.sensor('XYZ9'), isNull);
  });

  test('scan reads report headers: app crashes and Jetsam', () {
    final crashes = scan.appCrashes();
    expect(crashes, hasLength(9));
    expect(crashes.map((r) => r.name).toSet(), {'Instagram', 'Safari', 'Maps'});
    expect(scan.jetsamEvents(), hasLength(1));
    expect(scan.jetsamEvents(days: 30), hasLength(2));
    expect(scan.reports.where((r) => r.isResetCounter), hasLength(1));
  });

  test('correlation: same hardware clue grouped, confidence raised', () {
    final groups = Correlator(kb).correlate(scan.panics);
    final mask = groups.first;
    expect(mask.kind, ClueKind.sensorMask);
    expect(mask.value, 'iPhone15,2 0x140000');
    expect(mask.count, 12);
    expect(mask.component, 'Charging Port Flex / Power Button Flex');
    expect(mask.confidence, Confidence.high);
    expect(mask.first!.isBefore(mask.last!), isTrue);

    final tg0b = groups.firstWhere((g) => g.kind == ClueKind.missingSensor);
    expect(tg0b.value, 'TG0B');
    expect(tg0b.count, 3);
    expect(tg0b.component, contains('Battery'));
    // Mapped sensor (medium) seen 3 times → high.
    expect(tg0b.confidence, Confidence.high);
    expect(tg0b.isHardware, isTrue);

    // Non-hardware panics come after hardware clues.
    expect(groups.last.isHardware, isFalse);
  });

  test('a single occurrence is not raised', () {
    final one = Correlator(kb).correlate(scan.panics.take(1).toList());
    expect(one.single.count, 1);
    expect(one.single.confidence, Confidence.high); // rule's own confidence
    final tg = scan.panics
        .where((p) => p.report.missingSensors.isNotEmpty)
        .take(1)
        .toList();
    expect(Correlator(kb).correlate(tg).single.confidence, Confidence.medium);
  });

  test('health checklist from scan + device facts (English)', () {
    final r = HealthReport.build(
      s: const Strings(AppLang.en),
      knowledgeBase: kb,
      scan: scan,
      facts: MockIPhoneService.facts,
    );
    CheckStatus st(String id) => r.checks.firstWhere((c) => c.id == id).status;
    String val(String id) => r.checks.firstWhere((c) => c.id == id).value;
    expect(st('battery'), CheckStatus.warning);
    expect(val('battery'), 'Health 78 % · 843 cycles');
    expect(st('storage'), CheckStatus.warning);
    expect(val('storage'), '94 % used');
    expect(st('panics'), CheckStatus.problem);
    expect(val('panics'), '17 detected');
    expect(st('apps'), CheckStatus.warning);
    expect(val('apps'), '9 in 7 days');
    expect(st('jetsam'), CheckStatus.ok);
    expect(st('temperature'), CheckStatus.problem);
    expect(st('nand'), CheckStatus.ok);
    expect(val('baseband'), contains('2.00.01'));
    expect(st('devmode'), CheckStatus.info);
    expect(st('wifi'), CheckStatus.info);
    expect(r.overall, CheckStatus.problem);
    expect(r.mainIssue!.count, 12);
  });

  test('without a scan or facts: unavailable, never invented', () {
    final r = HealthReport.build(
      s: const Strings(AppLang.fr),
      knowledgeBase: kb,
    );
    expect(r.checks.every((c) => c.status == CheckStatus.unavailable), isTrue);
    expect(r.checks.first.value, 'Non disponible');
    expect(r.mainIssue, isNull);
  });

  test('French correlation texts', () {
    final groups = Correlator(kb, lang: AppLang.fr).correlate(scan.panics);
    final tg0b = groups.firstWhere((g) => g.value == 'TG0B');
    expect(tg0b.component, contains('Batterie'));
    expect(tg0b.note, contains('batterie'));
  });
}
