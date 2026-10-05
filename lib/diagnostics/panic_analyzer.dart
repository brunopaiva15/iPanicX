import '../l10n/strings.dart';
import '../models/diagnostic_result.dart';
import '../models/panic_report.dart';
import 'diagnostic_rule.dart';
import 'knowledge_base.dart';

/// Matches a [PanicReport] against the [KnowledgeBase].
class PanicAnalyzer {
  const PanicAnalyzer(this.knowledgeBase, {this.lang = AppLang.en});

  final KnowledgeBase knowledgeBase;

  /// Language of every text in the results. Passed explicitly because
  /// analysis runs in a background isolate.
  final AppLang lang;

  Strings get _s => Strings(lang);

  DiagnosticResult analyze(PanicReport report) {
    final codes = rawCodes(report);
    if (!report.isKernelReport) return _notAPanic(report, codes);
    final matches = <(DiagnosticRule, List<String>)>[];
    for (final rule in knowledgeBase.rules) {
      final evidence = rule.evaluate(report, lang: lang);
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
    final t = rule.textFor(lang);
    final technical = t.technicalReason ?? _defaultTechnicalReason(report);
    return DiagnosticResult(
      title: t.title,
      severity: rule.severity,
      summary: t.summary ?? _s.knownSignatureSummary,
      technicalReason: technical,
      suspectedComponents: t.suspectedComponents,
      possibleCauses: t.possibleCauses,
      recommendedActions: t.recommendedActions.isNotEmpty
          ? t.recommendedActions
          : [_s.defaultAction],
      confidence: rule.confidence,
      rawCodes: codes,
      evidence: evidence,
      matchedRuleId: rule.id,
      isHardwareRelated: rule.isHardware,
      disclaimer: t.note ?? _s.knownSignatureDisclaimer,
    );
  }

  DiagnosticResult _notAPanic(PanicReport report, List<String> codes) =>
      DiagnosticResult(
        title: _s.notPanicTitle,
        severity: Severity.unknown,
        summary: _s.notPanicSummary(
          _s.bugTypeLabel(report.bugType),
          report.bugType,
        ),
        recommendedActions: [_s.notPanicAction],
        confidence: Confidence.none,
        rawCodes: codes,
      );

  DiagnosticResult _unknown(PanicReport report, List<String> codes) {
    if (!report.hasPanicString) {
      return DiagnosticResult(
        title: _s.incompleteTitle,
        severity: Severity.unknown,
        summary: _s.incompleteSummary,
        technicalReason: report.parseWarnings.isEmpty
            ? null
            : report.parseWarnings.join('\n'),
        recommendedActions: _s.incompleteActions,
        confidence: Confidence.none,
        rawCodes: codes,
      );
    }
    return DiagnosticResult(
      title: _s.unknownTitle,
      severity: Severity.unknown,
      summary: _s.unknownSummary,
      technicalReason: _defaultTechnicalReason(report),
      recommendedActions: _s.unknownActions,
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
