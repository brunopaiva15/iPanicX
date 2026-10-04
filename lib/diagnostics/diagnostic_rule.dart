import '../models/diagnostic_result.dart';
import '../models/panic_report.dart';

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

  bool matchesDevice(String? product) {
    if (devices.isEmpty) return true;
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

  /// Returns the evidence (human readable) when the rule matches, else null.
  List<String>? evaluate(PanicReport report) {
    if (!hasCriteria) return null;
    if (!matchesDevice(report.product)) return null;
    final evidence = <String>[];
    if (devices.isNotEmpty) evidence.add('Device ${report.product}');

    final haystack = normalize(
      [
        matchableText(report.panicString),
        report.panickedProcess ?? '',
      ].join('\n'),
    );
    for (final term in panicContains) {
      if (!haystack.contains(normalize(term))) return null;
      evidence.add('“$term”');
    }
    if (panicContainsAny.isNotEmpty) {
      final hits = panicContainsAny
          .where((t) => haystack.contains(normalize(t)))
          .toList();
      if (hits.length < minAny) return null;
      evidence.addAll(hits.map((t) => '“$t”'));
    }
    if (headlineContainsAny.isNotEmpty) {
      final line = normalize(report.panicLine ?? '');
      final hit = headlineContainsAny.where((t) => line.contains(normalize(t)));
      if (hit.isEmpty) return null;
      evidence.add('Panic line “${hit.first}”');
    }
    for (final term in panicNotContains) {
      if (haystack.contains(normalize(term))) return null;
    }
    if (kextsAny.isNotEmpty) {
      final kexts = report.backtraceKexts.map((k) => k.toLowerCase()).toSet();
      final hit = kextsAny.where((k) => kexts.contains(k.toLowerCase()));
      if (hit.isEmpty) return null;
      evidence.add('Kext ${hit.first}');
    }
    if (sensorMask != null) {
      if (report.sensorMask != sensorMask) return null;
      evidence.add('Sensor mask ${PanicReport.formatHex(sensorMask!)}');
    }
    if (missingSensorsAny.isNotEmpty) {
      final missing = report.missingSensors.map((s) => s.toLowerCase()).toSet();
      final hit = missingSensorsAny.where(
        (s) => missing.contains(s.toLowerCase()),
      );
      if (hit.isEmpty) return null;
      evidence.add('Missing sensor ${hit.first}');
    }
    return evidence;
  }
}
