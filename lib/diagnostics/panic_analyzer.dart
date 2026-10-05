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
    var summary = t.summary ?? _s.knownSignatureSummary;
    var technical = t.technicalReason ?? _defaultTechnicalReason(report);
    var components = t.suspectedComponents;
    var confidence = rule.confidence;
    final sourceKeys = [...rule.sources];

    if (rule.decodeSensorMask && report.sensorMask != null) {
      final mask = PanicReport.formatHex(report.sensorMask!);
      final d = knowledgeBase.decodeSmcMask(report.product, report.sensorMask);
      if (d != null && d.isMapped) {
        components = _partNames(d.hits);
        summary = _s.smcDecodedSummary(components.join(', '));
        technical = [
          _s.smcDecodedReason(mask, d.model, _codeList(d.hits)),
          if (d.unknownBits != 0)
            _s.smcUnknownBits(PanicReport.formatHex(d.unknownBits)),
          if (d.alternative.isNotEmpty)
            _s.smcAlternative(mask, _codeList(d.alternative)),
          ...{
            for (final c in [...d.hits, ...d.alternative]) ?c.noteIn(lang),
          },
        ].join('\n');
        confidence = d.confidence;
        evidence = [...evidence, _s.evidenceMaskTable(d.model)];
        sourceKeys.addAll(d.sourceKeys);
      } else if (d != null) {
        technical = [?technical, _s.smcNotMapped(mask, d.model)].join('\n');
      }
    }

    if (rule.decodeMissingSensors && report.missingSensors.isNotEmpty) {
      final known = <String, SensorInfo>{
        for (final name in report.missingSensors)
          if (knowledgeBase.sensor(name) != null)
            name: knowledgeBase.sensor(name)!,
      };
      final unknown = report.missingSensors
          .where((n) => !known.containsKey(n))
          .toList();
      if (known.isNotEmpty) {
        components = {
          for (final i in known.values) i.componentIn(lang),
        }.toList();
        technical = [
          _s.missingSensorsReason(
            known.entries
                .map((e) => '${e.key} → ${e.value.componentIn(lang)}')
                .join(', '),
          ),
          if (unknown.isNotEmpty) _s.missingSensorsUnknown(unknown.join(', ')),
          ...{for (final i in known.values) ?i.noteIn(lang)},
        ].join('\n');
        if (unknown.isEmpty) confidence = Confidence.high;
      }
    }

    if (rule.decodeI2cBus) {
      final bus = _i2cBus
          .firstMatch(DiagnosticRule.matchableText(report.panicString))
          ?.group(1)
          ?.toLowerCase();
      final found = bus == null
          ? const <(I2cModel, String)>[]
          : knowledgeBase.i2cChips(report.product, bus);
      if (bus != null && found.isNotEmpty) {
        components = [for (final (_, chips) in found) _s.i2cChips(bus, chips)];
        technical = [
          for (final (m, chips) in found) _s.i2cReason(bus, m.model, chips),
          ?technical,
        ].join('\n');
        for (final (m, _) in found) {
          sourceKeys.addAll(m.sources);
        }
      }
    }

    return DiagnosticResult(
      title: t.title,
      severity: rule.severity,
      summary: summary,
      technicalReason: technical,
      suspectedComponents: components,
      possibleCauses: t.possibleCauses,
      recommendedActions: t.recommendedActions.isNotEmpty
          ? t.recommendedActions
          : [_s.defaultAction],
      confidence: confidence,
      rawCodes: codes,
      evidence: evidence,
      matchedRuleId: rule.id,
      isHardwareRelated: rule.isHardware,
      disclaimer: t.note ?? _s.knownSignatureDisclaimer,
      sources: [for (final src in knowledgeBase.sourcesFor(sourceKeys)) '$src'],
    );
  }

  static final _i2cBus = RegExp(r'\b(i2c\d)\b', caseSensitive: false);

  /// Part names in [lang], each once, in table order.
  List<String> _partNames(List<SmcCode> codes) =>
      {for (final c in codes) knowledgeBase.partName(c.part, lang)}.toList();

  /// "0x40000 → Charge Port Flex, 0x100000 → Power Button Flex".
  String _codeList(List<SmcCode> codes) => codes
      .map(
        (c) =>
            '${PanicReport.formatHex(c.mask)} → ${knowledgeBase.partName(c.part, lang)}',
      )
      .join(', ');

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
