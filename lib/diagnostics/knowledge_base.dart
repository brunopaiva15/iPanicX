import 'dart:convert';

import '../l10n/strings.dart';
import 'diagnostic_rule.dart';

/// Part that usually carries a sensor reported as missing by
/// thermalmonitord (`"sensors"` in the JSON).
class SensorInfo {
  const SensorInfo({required this.component, this.fr, this.note, this.noteFr});

  final String component;
  final String? fr;
  final String? note;
  final String? noteFr;

  String componentIn(AppLang lang) =>
      lang == AppLang.fr ? (fr ?? component) : component;
  String? noteIn(AppLang lang) => lang == AppLang.fr ? (noteFr ?? note) : note;
}

/// Panic signatures known to iPanicX.
///
/// The V0 base is intentionally small and is **not** exhaustive.
class KnowledgeBase {
  const KnowledgeBase({
    required this.rules,
    this.version,
    this.warnings = const [],
    this.sensors = const {},
  });

  static const assetPath = 'assets/diagnostics/knowledge_base.json';

  final List<DiagnosticRule> rules;
  final String? version;

  /// Rules that were skipped because they are malformed.
  final List<String> warnings;

  /// Sensor name (lower case) → part.
  final Map<String, SensorInfo> sensors;

  SensorInfo? sensor(String name) => sensors[name.toLowerCase()];

  static const empty = KnowledgeBase(rules: []);

  factory KnowledgeBase.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Knowledge base must be a JSON object.');
    }
    final rules = <DiagnosticRule>[];
    final warnings = <String>[];
    final rawRules = decoded['rules'];
    if (rawRules is List) {
      for (var i = 0; i < rawRules.length; i++) {
        final r = rawRules[i];
        try {
          if (r is! Map<String, dynamic>) {
            throw const FormatException('not an object');
          }
          final rule = DiagnosticRule.fromJson(r);
          if (!rule.hasCriteria) {
            throw const FormatException('rule has no matching criteria');
          }
          rules.add(rule);
        } on FormatException catch (e) {
          warnings.add('Rule #$i skipped: ${e.message}');
        }
      }
    }
    final sensors = <String, SensorInfo>{};
    final rawSensors = decoded['sensors'];
    if (rawSensors is Map<String, dynamic>) {
      for (final e in rawSensors.entries) {
        final v = e.value;
        if (e.key.startsWith('_') || v is! Map<String, dynamic>) continue;
        final component = v['component']?.toString();
        if (component == null) continue;
        sensors[e.key.toLowerCase()] = SensorInfo(
          component: component,
          fr: v['fr']?.toString(),
          note: v['note']?.toString(),
          noteFr: v['noteFr']?.toString(),
        );
      }
    }
    return KnowledgeBase(
      rules: rules,
      version: decoded['version']?.toString(),
      warnings: warnings,
      sensors: sensors,
    );
  }
}
