import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/diagnostics/knowledge_base.dart';
import 'package:ipanicx/diagnostics/panic_analyzer.dart';
import 'package:ipanicx/diagnostics/panic_parser.dart';
import 'package:ipanicx/models/diagnostic_result.dart';

import '../helpers.dart';

void main() {
  final kb = loadKnowledgeBase();
  final analyzer = PanicAnalyzer(kb);
  const parser = PanicParser();

  test('knowledge base loads without skipped rules', () {
    expect(kb.rules, isNotEmpty);
    expect(kb.warnings, isEmpty);
    expect(kb.rules.map((r) => r.id), contains('smc_bsc_iphone15_2_140000'));
  });

  group('iPhone15,2 + SMC BSC failure + sensor mask 0x140000', () {
    final result = analyzer.analyze(parser.parse(loadSample(smcSample)));

    test('matches the specific example rule', () {
      expect(result.matchedRuleId, 'smc_bsc_iphone15_2_140000');
      expect(result.title, 'SMC Sensor Failure');
      expect(result.severity, Severity.high);
      expect(result.confidence, Confidence.high);
      expect(result.isHardwareRelated, isTrue);
    });

    test('suspects charging port flex and power button flex', () {
      expect(result.suspectedComponents, [
        'Charging Port Flex',
        'Power Button Flex',
      ]);
      expect(result.possibleCauses, contains('Liquid damage'));
      expect(result.recommendedActions, isNotEmpty);
    });

    test('includes the hardware-inspection disclaimer', () {
      expect(
        result.disclaimer,
        'This diagnosis is based on a known panic signature and should be '
        'confirmed by hardware inspection.',
      );
    });

    test('lists evidence and raw codes', () {
      expect(result.evidence, contains('Device iPhone15,2'));
      expect(result.evidence, contains('Sensor mask 0x140000'));
      expect(result.evidence, contains('“SMC BSC failure”'));
      expect(
        result.rawCodes,
        containsAll(['SMC PANIC', 'SMC BSC failure', 'TAOP', 'TAOJ']),
      );
      expect(result.rawCodes, contains('sensor mask 0x140000 (1310720)'));
    });
  });

  test('same signature on another model falls back to the generic rule', () {
    final content = loadSample(
      smcSample,
    ).replaceAll('iPhone15,2', 'iPhone16,1');
    final result = analyzer.analyze(parser.parse(content));
    expect(result.matchedRuleId, 'smc_bsc_generic');
    expect(result.confidence, Confidence.medium);
    expect(result.suspectedComponents, isNot(contains('Charging Port Flex')));
  });

  test('a different sensor mask does not match the specific rule', () {
    final content = loadSample(smcSample).replaceAll('1310720', '262144');
    final result = analyzer.analyze(parser.parse(content));
    expect(result.matchedRuleId, 'smc_bsc_generic');
  });

  test('unknown panic returns Unknown Hardware Panic with details', () {
    final report = parser.parse(loadSample(unknownSample));
    final result = analyzer.analyze(report);
    expect(result.title, 'Unknown Hardware Panic');
    expect(result.isKnownSignature, isFalse);
    expect(result.confidence, Confidence.none);
    expect(
      result.summary,
      contains('not currently present in the iPanicX knowledge base'),
    );
    expect(result.technicalReason, contains('AppleH16CamIn'));
    expect(result.rawCodes, contains('bug_type 210'));
    expect(report.product, 'iPhone15,2');
    expect(report.osVersion, '26.0.1');
  });

  test('panic without panic string is reported as incomplete', () {
    final result = analyzer.analyze(
      parser.parse('{"bug_type":"210"}\n{"product":"iPhone15,2"}'),
    );
    expect(result.title, 'Incomplete Panic Report');
    expect(result.isKnownSignature, isFalse);
  });

  test('loaded kexts inventory does not trigger text rules', () {
    // AppleANS2Controller only appears in the "loaded kexts" list.
    const content =
        '{"bug_type":"210"}\n{"product":"iPhone15,2","panicString":'
        '"panic(cpu 2 caller 0x1): unexpected state.\\n\\nloaded kexts:\\n'
        'com.apple.driver.AppleANS2Controller 1\\ncom.apple.AGXG15P 1\\n"}';
    final result = analyzer.analyze(parser.parse(content));
    expect(result.isKnownSignature, isFalse);
  });

  test('missing thermal sensor rule', () {
    const content =
        '{"bug_type":"210"}\n{"product":"iPhone12,1","panicString":'
        '"panic(cpu 0 caller 0x1): userspace watchdog timeout: no successful checkins '
        'from thermalmonitord\\nMissing sensor(s): mic1\\n"}';
    final result = analyzer.analyze(parser.parse(content));
    expect(result.matchedRuleId, 'thermalmonitord_missing_sensor');
    expect(result.rawCodes, contains('missing sensors: mic1'));
  });

  group('rule engine', () {
    KnowledgeBase kbOf(String rules) =>
        KnowledgeBase.fromJsonString('{"rules": $rules}');
    final report = parser.parse(
      '{"product":"iPhone15,3","panicString":"panic(cpu 0 caller 0x1): FOO  BAR baz"}',
    );

    test('matching is case-insensitive and whitespace-tolerant', () {
      final r = PanicAnalyzer(
        kbOf('[{"id":"a","title":"A","panicContains":["foo bar"]}]'),
      ).analyze(report);
      expect(r.matchedRuleId, 'a');
    });

    test('panicNotContains excludes a rule', () {
      final r = PanicAnalyzer(
        kbOf(
          '[{"id":"a","title":"A","panicContains":["foo"],"panicNotContains":["baz"]}]',
        ),
      ).analyze(report);
      expect(r.isKnownSignature, isFalse);
    });

    test('minAny requires several optional terms', () {
      final rules =
          '[{"id":"a","title":"A","panicContainsAny":["foo","nope","baz"],"minAny":3}]';
      expect(
        PanicAnalyzer(kbOf(rules)).analyze(report).isKnownSignature,
        isFalse,
      );
    });

    test('device wildcard', () {
      final r = PanicAnalyzer(
        kbOf(
          '[{"id":"a","title":"A","device":"iPhone15,*","panicContains":["foo"]}]',
        ),
      ).analyze(report);
      expect(r.matchedRuleId, 'a');
    });

    test('most specific rule wins', () {
      final r = PanicAnalyzer(
        kbOf(
          '['
          '{"id":"generic","title":"G","panicContains":["foo"]},'
          '{"id":"specific","title":"S","device":"iPhone15,3","panicContains":["foo","bar"]}'
          ']',
        ),
      ).analyze(report);
      expect(r.matchedRuleId, 'specific');
    });

    test('malformed rules are skipped with a warning', () {
      final kb = kbOf('[{"id":"x"},{"id":"y","title":"Y"},"oops"]');
      expect(kb.rules, isEmpty);
      expect(kb.warnings, hasLength(3));
    });
  });
}
