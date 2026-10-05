import '../l10n/strings.dart';

enum Severity {
  low,
  medium,
  high,
  unknown;

  static Severity parse(String? value) => switch (value?.toLowerCase()) {
    'low' => low,
    'medium' => medium,
    'high' || 'critical' => high,
    _ => unknown,
  };

  String get label => tr.severityLabel(name);
}

enum Confidence {
  low,
  medium,
  high,
  none;

  static Confidence parse(String? value) => switch (value?.toLowerCase()) {
    'low' => low,
    'medium' => medium,
    'high' => high,
    _ => none,
  };

  String get label => tr.confidenceLabel(name);

  int get rank => switch (this) {
    none => 0,
    low => 1,
    medium => 2,
    high => 3,
  };
}

/// Human-readable outcome of analysing one panic.
class DiagnosticResult {
  const DiagnosticResult({
    required this.title,
    required this.severity,
    required this.summary,
    required this.confidence,
    this.technicalReason,
    this.suspectedComponents = const [],
    this.possibleCauses = const [],
    this.recommendedActions = const [],
    this.rawCodes = const [],
    this.evidence = const [],
    this.matchedRuleId,
    this.isHardwareRelated = false,
    this.disclaimer,
  });

  final String title;
  final Severity severity;
  final String summary;
  final String? technicalReason;
  final List<String> suspectedComponents;
  final List<String> possibleCauses;
  final List<String> recommendedActions;
  final Confidence confidence;

  /// Codes detected in the panic (SMC keys, sensor mask, bug type…).
  final List<String> rawCodes;

  /// Why the matched rule applies (terms found, mask, device…).
  final List<String> evidence;

  /// Knowledge-base rule id, or null for an unknown signature.
  final String? matchedRuleId;
  final bool isHardwareRelated;
  final String? disclaimer;

  bool get isKnownSignature => matchedRuleId != null;
}
