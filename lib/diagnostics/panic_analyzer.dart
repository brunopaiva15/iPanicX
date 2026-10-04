import '../models/diagnostic_result.dart';
import '../models/panic_report.dart';
import 'diagnostic_rule.dart';
import 'knowledge_base.dart';

/// Matches a [PanicReport] against the [KnowledgeBase].
class PanicAnalyzer {
  const PanicAnalyzer(this.knowledgeBase);

  final KnowledgeBase knowledgeBase;

  static const knownSignatureDisclaimer =
      'This diagnosis is based on a known panic signature and should be '
      'confirmed by hardware inspection.';

  DiagnosticResult analyze(PanicReport report) {
    final codes = rawCodes(report);
    if (!report.isKernelReport) return _notAPanic(report, codes);
    final matches = <(DiagnosticRule, List<String>)>[];
    for (final rule in knowledgeBase.rules) {
      final evidence = rule.evaluate(report);
      if (evidence != null) matches.add((rule, evidence));
    }
    if (matches.isEmpty) return _unknown(report, codes);
    matches.sort((a, b) {
      final s = b.$1.specificity.compareTo(a.$1.specificity);
      return s != 0 ? s : b.$1.confidence.rank.compareTo(a.$1.confidence.rank);
    });
    final (rule, evidence) = matches.first;
    return _fromRule(rule, report, codes, evidence);
  }

  DiagnosticResult _fromRule(
    DiagnosticRule rule,
    PanicReport report,
    List<String> codes,
    List<String> evidence,
  ) {
    final technical = rule.technicalReason ?? _defaultTechnicalReason(report);
    return DiagnosticResult(
      title: rule.title,
      severity: rule.severity,
      summary:
          rule.summary ??
          'This panic matches a known signature in the iPaniX knowledge base.',
      technicalReason: technical,
      suspectedComponents: rule.suspectedComponents,
      possibleCauses: rule.possibleCauses,
      recommendedActions: rule.recommendedActions.isNotEmpty
          ? rule.recommendedActions
          : const [
              'Inspect the suspected components and their connectors before '
                  'restoring the device.',
            ],
      confidence: rule.confidence,
      rawCodes: codes,
      evidence: evidence,
      matchedRuleId: rule.id,
      isHardwareRelated: rule.isHardware,
      disclaimer: rule.note ?? knownSignatureDisclaimer,
    );
  }

  DiagnosticResult _notAPanic(PanicReport report, List<String> codes) =>
      DiagnosticResult(
        title: 'Not a Kernel Panic',
        severity: Severity.unknown,
        summary:
            'This file is a ${report.reportKind.toLowerCase()} report '
            '(bug_type ${report.bugType}), not a kernel panic. iPaniX only '
            'diagnoses kernel panics in this version.',
        recommendedActions: const [
          'Open a panic-full or panic-base file to get a hardware diagnosis.',
        ],
        confidence: Confidence.none,
        rawCodes: codes,
      );

  DiagnosticResult _unknown(PanicReport report, List<String> codes) {
    if (!report.hasPanicString) {
      return DiagnosticResult(
        title: 'Incomplete Panic Report',
        severity: Severity.unknown,
        summary:
            'The file was read, but no panic description could be found '
            'in it. It may be truncated or use an unsupported format.',
        technicalReason: report.parseWarnings.isEmpty
            ? null
            : report.parseWarnings.join('\n'),
        recommendedActions: const [
          'Open the raw panic to inspect it manually.',
          'Scan again after the next restart to get a fresh report.',
        ],
        confidence: Confidence.none,
        rawCodes: codes,
      );
    }
    return DiagnosticResult(
      title: 'Unknown Hardware Panic',
      severity: Severity.unknown,
      summary:
          'The panic was successfully parsed, but this signature is not '
          'currently present in the iPaniX knowledge base.',
      technicalReason: _defaultTechnicalReason(report),
      recommendedActions: const [
        'Review the panic string and detected codes below.',
        'Check whether the same panic repeats across several reports.',
      ],
      confidence: Confidence.none,
      rawCodes: codes,
    );
  }

  static String? _defaultTechnicalReason(PanicReport report) => report.headline;

  /// Codes worth surfacing to a technician.
  static List<String> rawCodes(PanicReport report) {
    final codes = <String>[];
    if (report.bugType != null) codes.add('bug_type ${report.bugType}');
    final panic = DiagnosticRule.matchableText(report.panicString);
    for (final tag in [
      'SMC PANIC',
      'SMC BSC failure',
      'OUTBOX1 not ready',
      'AOP PANIC',
      'AppleSensorHub',
      'ANS2',
      'watchdog timeout',
      'thermalmonitord',
    ]) {
      if (panic.toLowerCase().contains(tag.toLowerCase())) codes.add(tag);
    }
    codes.addAll(report.sensorKeys);
    if (report.sensorMask != null) {
      codes.add('sensor mask ${report.sensorMaskHex} (${report.sensorMask})');
    }
    if (report.panicFlags != null) codes.add('panicFlags ${report.panicFlags}');
    if (report.missingSensors.isNotEmpty) {
      codes.add('missing sensors: ${report.missingSensors.join(', ')}');
    }
    return codes;
  }
}
