import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/models/diagnostic_file.dart';
import 'package:ipanicx/models/scan_result.dart';
import 'package:ipanicx/services/diagnostic_service.dart';
import 'package:ipanicx/services/mock_iphone_service.dart';

import '../helpers.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ipanicx_scan_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  MockIPhoneService mock([MockScenario s = MockScenario.connected]) =>
      MockIPhoneService(
        scenario: s,
        sampleLoader: sampleLoader,
        workRoot: tmp,
        latency: Duration.zero,
      );

  test('full mock scan: copy → parse → analyse → health summary', () async {
    final iphone = mock();
    await iphone.start();
    final service = DiagnosticService(
      iphone: iphone,
      knowledgeBase: loadKnowledgeBase(),
    );
    final scan = await service.scan();

    expect(scan.panics, hasLength(17));
    expect(scan.countOf(DiagnosticFileType.jetsamEvent), 2);
    expect(scan.countOf(DiagnosticFileType.resetCounter), 1);
    expect(scan.forcedResets, hasLength(2));
    expect(scan.health.forcedResetCount, 2);
    expect(
      scan.files.any((f) => f.relativePath.startsWith('Retired/')),
      isTrue,
    );

    final latest = scan.latestPanic!;
    expect(latest.file.name, startsWith('panic-full-'));
    expect(latest.result.title, 'SMC Sensor Failure');
    expect(latest.result.suspectedComponents, [
      'Charging Port Flex',
      'Power Button Flex',
    ]);
    // Newest first.
    for (var i = 1; i < scan.panics.length; i++) {
      expect(scan.panics[i - 1].date!.isBefore(scan.panics[i].date!), isFalse);
    }

    final h = scan.health;
    expect(h.panicCount, 17);
    expect(h.mostCommonPanic, 'SMC Sensor Failure');
    expect(h.mostCommonCount, 12);
    expect(h.verdict, HealthVerdict.hardwareIssueLikely);
    expect(h.latest, latest.date);
    iphone.dispose();
  });

  test('scan without panic-full files', () async {
    final iphone = mock(MockScenario.noPanics);
    await iphone.start();
    final scan = await DiagnosticService(
      iphone: iphone,
      knowledgeBase: loadKnowledgeBase(),
      useIsolate: false,
    ).scan();
    expect(scan.panics, isEmpty);
    expect(scan.files, isNotEmpty);
    expect(scan.health.verdict, HealthVerdict.noPanics);
    iphone.dispose();
  });

  test('only unknown panics → cause not determined', () {
    final panics = [
      DiagnosticService.analyzeContent(
        loadKnowledgeBase(),
        DiagnosticFile.fromPath(path: '/x/$unknownSample', rootDirectory: '/x'),
        loadSample(unknownSample),
      ),
    ];
    final h = DeviceHealthSummary.fromPanics(panics);
    expect(h.verdict, HealthVerdict.undetermined);
    expect(h.mostCommonPanic, startsWith('"AppleH16CamIn'));
  });

  test('analyzeLocalFile reads a .ips from disk', () async {
    final f = File('${tmp.path}/$smcSample')
      ..writeAsStringSync(loadSample(smcSample));
    final iphone = mock();
    final panic = await DiagnosticService(
      iphone: iphone,
      knowledgeBase: loadKnowledgeBase(),
    ).analyzeLocalFile(f.path);
    expect(panic.result.matchedRuleId, 'smc_bsc_iphone15_2_140000');
    iphone.dispose();
  });
}
