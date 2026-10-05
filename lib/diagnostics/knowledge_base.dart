import 'dart:convert';

import 'diagnostic_rule.dart';

/// Panic signatures known to iPanicX.
///
/// The V0 base is intentionally small and is **not** exhaustive.
class KnowledgeBase {
  const KnowledgeBase({
    required this.rules,
    this.version,
    this.warnings = const [],
  });

  static const assetPath = 'assets/diagnostics/knowledge_base.json';

  final List<DiagnosticRule> rules;
  final String? version;

  /// Rules that were skipped because they are malformed.
  final List<String> warnings;

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
    return KnowledgeBase(
      rules: rules,
      version: decoded['version']?.toString(),
      warnings: warnings,
    );
  }
}
