import '../l10n/strings.dart';
import '../models/diagnostic_result.dart';
import '../models/panic_report.dart';

/// User-facing texts of a rule in one language.
class RuleText {
  const RuleText({
    required this.title,
    this.summary,
    this.technicalReason,
    this.suspectedComponents = const [],
    this.possibleCauses = const [],
    this.recommendedActions = const [],
    this.note,
  });

  final String title;
  final String? summary;
  final String? technicalReason;
  final List<String> suspectedComponents;
  final List<String> possibleCauses;
  final List<String> recommendedActions;
  final String? note;
}

/// A single knowledge-base entry (see `assets/diagnostics/knowledge_base.json`).
///
/// A rule matches when **every** criterion it defines is satisfied. Text
/// criteria are matched case-insensitively against the panic string (plus
/// the panicked process name) with whitespace collapsed:
///  * `device` / `devices`: product types; `*` suffix allowed (`iPhone15,*`);
///  * `panicContains`: all terms must appear;
///  * `panicContainsAny` + `minAny` (default 1): at least `minAny` terms;
///  * `panicNotContains`: none of these terms may appear;
///  * `headlineContainsAny`: one term appears in the `panic(` line itself;
///  * `kextsAny`: one of these kexts appears in the backtrace;
///  * `sensorMask`: exact SMC sensor mask (hex `"0x140000"` or decimal);
///  * `missingSensorsAny`: one of these sensors is reported missing.
///
/// Options (not criteria):
///  * `decodeSensorMask`: name the parts from the per-model SMC mask table;
///  * `decodeMissingSensors`: name the parts carrying the missing sensors;
///  * `decodeI2cBus`: name the chips on the reported I²C bus for the model;
///  * `sources`: keys of the top-level `sources` the rule is based on.
class DiagnosticRule {
  const DiagnosticRule({
    required this.id,
    required this.title,
    this.devices = const [],
    this.panicContains = const [],
    this.panicContainsAny = const [],
    this.minAny = 1,
    this.panicNotContains = const [],
    this.headlineContainsAny = const [],
    this.kextsAny = const [],
    this.sensorMask,
    this.missingSensorsAny = const [],
    this.category = 'unknown',
    this.severity = Severity.unknown,
    this.confidence = Confidence.low,
    this.summary,
    this.technicalReason,
    this.suspectedComponents = const [],
    this.possibleCauses = const [],
    this.recommendedActions = const [],
    this.note,
    this.translations = const {},
    this.sources = const [],
    this.decodeSensorMask = false,
    this.decodeMissingSensors = false,
    this.decodeI2cBus = false,
  });

  factory DiagnosticRule.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) {
      final v = json[key];
      if (v == null) return const [];
      if (v is String) return [v];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    final id = json['id']?.toString();
    final title = json['title']?.toString();
    if (id == null || title == null) {
      throw const FormatException('Rule requires "id" and "title".');
    }
    final minAny = json['minAny'];
    final translations = <String, Map<String, dynamic>>{};
    for (final lang in AppLang.values) {
      final t = json[lang.name];
      if (t is Map<String, dynamic>) translations[lang.name] = t;
    }
    return DiagnosticRule(
      id: id,
      title: title,
      devices: [...list('device'), ...list('devices')],
      panicContains: list('panicContains'),
      panicContainsAny: list('panicContainsAny'),
      minAny: minAny is int && minAny > 0 ? minAny : 1,
      panicNotContains: list('panicNotContains'),
      headlineContainsAny: list('headlineContainsAny'),
      kextsAny: list('kextsAny'),
      sensorMask: parseMask(json['sensorMask']),
      missingSensorsAny: list('missingSensorsAny'),
      category: json['category']?.toString() ?? 'unknown',
      severity: Severity.parse(json['severity']?.toString()),
      confidence: Confidence.parse(json['confidence']?.toString()),
      summary: json['summary']?.toString(),
      technicalReason: json['technicalReason']?.toString(),
      suspectedComponents: list('suspectedComponents'),
      possibleCauses: list('possibleCauses'),
      recommendedActions: list('recommendedActions'),
      note: json['note']?.toString(),
      translations: {
        for (final e in translations.entries) e.key: _translation(e.value),
      },
      sources: list('sources'),
      decodeSensorMask: json['decodeSensorMask'] == true,
      decodeMissingSensors: json['decodeMissingSensors'] == true,
      decodeI2cBus: json['decodeI2cBus'] == true,
    );
  }

  /// Partial override: missing fields keep the English value (null / empty
  /// here, resolved in [textFor]).
  static RuleText _translation(Map<String, dynamic> t) {
    List<String> list(String key) {
      final v = t[key];
      if (v is String) return [v];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return RuleText(
      title: t['title']?.toString() ?? '',
      summary: t['summary']?.toString(),
      technicalReason: t['technicalReason']?.toString(),
      suspectedComponents: list('suspectedComponents'),
      possibleCauses: list('possibleCauses'),
      recommendedActions: list('recommendedActions'),
      note: t['note']?.toString(),
    );
  }

  /// Texts in [lang], falling back field by field to English.
  RuleText textFor(AppLang lang) {
    final t = translations[lang.name];
    List<String> pick(List<String>? tr, List<String> en) =>
        tr != null && tr.isNotEmpty ? tr : en;
    return RuleText(
      title: (t?.title.isNotEmpty ?? false) ? t!.title : title,
      summary: t?.summary ?? summary,
      technicalReason: t?.technicalReason ?? technicalReason,
      suspectedComponents: pick(t?.suspectedComponents, suspectedComponents),
      possibleCauses: pick(t?.possibleCauses, possibleCauses),
      recommendedActions: pick(t?.recommendedActions, recommendedActions),
      note: t?.note ?? note,
    );
  }

  final String id;
  final String title;
  final List<String> devices;
  final List<String> panicContains;
  final List<String> panicContainsAny;
  final int minAny;
  final List<String> panicNotContains;

  /// Terms searched only in the `panic(cpu …)` line (strongest signal).
  final List<String> headlineContainsAny;
  final List<String> kextsAny;
  final int? sensorMask;
  final List<String> missingSensorsAny;

  /// `hardware`, `software` or `unknown`.
  final String category;
  final Severity severity;
  final Confidence confidence;
  final String? summary;
  final String? technicalReason;
  final List<String> suspectedComponents;
  final List<String> possibleCauses;
  final List<String> recommendedActions;
  final String? note;

  /// Per-language overrides keyed by [AppLang.name] (`"fr"` in the JSON).
  final Map<String, RuleText> translations;

  /// Keys of [KnowledgeBase.sources].
  final List<String> sources;
  final bool decodeSensorMask;
  final bool decodeMissingSensors;
  final bool decodeI2cBus;

  bool get isHardware => category == 'hardware';

  /// A rule needs at least one positive criterion besides the device.
  bool get hasCriteria =>
      panicContains.isNotEmpty ||
      panicContainsAny.isNotEmpty ||
      headlineContainsAny.isNotEmpty ||
      kextsAny.isNotEmpty ||
      sensorMask != null ||
      missingSensorsAny.isNotEmpty;

  /// Higher = more specific. Used to choose between several matching rules.
  int get specificity =>
      (devices.isNotEmpty ? 4 : 0) +
      (sensorMask != null ? 8 : 0) +
      (missingSensorsAny.isNotEmpty ? 3 : 0) +
      (kextsAny.isNotEmpty ? 2 : 0) +
      (headlineContainsAny.isNotEmpty ? 3 : 0) +
      panicContains.length * 2 +
      (panicContainsAny.isNotEmpty ? minAny : 0);

  static int? parseMask(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    final s = raw.toString().trim().toLowerCase();
    if (s.startsWith('0x')) return int.tryParse(s.substring(2), radix: 16);
    return int.tryParse(s);
  }

  /// Panic text without the `loaded kexts:` inventory, which lists every
  /// driver on every panic and would otherwise cause false matches.
  static String matchableText(String? panicString) {
    if (panicString == null) return '';
    final cut = panicString.toLowerCase().indexOf('loaded kexts:');
    return cut < 0 ? panicString : panicString.substring(0, cut);
  }

  /// Lower-case, whitespace-collapsed form used for all text matching.
  static String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  bool matchesDevice(String? product) =>
      devices.isEmpty || deviceIn(devices, product);

  /// [product] is one of [devices] (`*` suffix allowed).
  static bool deviceIn(List<String> devices, String? product) {
    if (product == null) return false;
    for (final d in devices) {
      if (d == '*') return true;
      if (d.endsWith('*')) {
        if (product.startsWith(d.substring(0, d.length - 1))) return true;
      } else if (d == product) {
        return true;
      }
    }
    return false;
  }

  bool matches(PanicReport report) => evaluate(report) != null;

  /// Returns the evidence (human readable, in [lang]) when the rule matches,
  /// else null.
  List<String>? evaluate(PanicReport report, {AppLang lang = AppLang.en}) {
    if (!hasCriteria) return null;
    if (!matchesDevice(report.product)) return null;
    final s = Strings(lang);
    final evidence = <String>[];
    if (devices.isNotEmpty) evidence.add(s.evidenceDevice(report.product));

    final haystack = normalize(
      [
        matchableText(report.panicString),
        report.panickedProcess ?? '',
      ].join('\n'),
    );
    for (final term in panicContains) {
      if (!haystack.contains(normalize(term))) return null;
      evidence.add(s.evidenceTerm(term));
    }
    if (panicContainsAny.isNotEmpty) {
      final hits = panicContainsAny
          .where((t) => haystack.contains(normalize(t)))
          .toList();
      if (hits.length < minAny) return null;
      evidence.addAll(hits.map(s.evidenceTerm));
    }
    if (headlineContainsAny.isNotEmpty) {
      final line = normalize(report.panicLine ?? '');
      final hit = headlineContainsAny.where((t) => line.contains(normalize(t)));
      if (hit.isEmpty) return null;
      evidence.add(s.evidencePanicLine(hit.first));
    }
    for (final term in panicNotContains) {
      if (haystack.contains(normalize(term))) return null;
    }
    if (kextsAny.isNotEmpty) {
      final kexts = report.backtraceKexts.map((k) => k.toLowerCase()).toSet();
      final hit = kextsAny.where((k) => kexts.contains(k.toLowerCase()));
      if (hit.isEmpty) return null;
      evidence.add(s.evidenceKext(hit.first));
    }
    if (sensorMask != null) {
      if (report.sensorMask != sensorMask) return null;
      evidence.add(s.evidenceMask(PanicReport.formatHex(sensorMask!)));
    }
    if (missingSensorsAny.isNotEmpty) {
      final missing = report.missingSensors.map((s) => s.toLowerCase()).toSet();
      final hit = missingSensorsAny.where(
        (s) => missing.contains(s.toLowerCase()),
      );
      if (hit.isEmpty) return null;
      evidence.add(s.evidenceMissing(hit.first));
    }
    return evidence;
  }
}
