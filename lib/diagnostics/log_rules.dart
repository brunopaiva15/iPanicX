/// Highlighting of live log lines (`idevicesyslog`).
///
/// The first matching rule wins, so the most serious come first.
enum LogLevel { normal, info, warning, problem }

class LogRule {
  const LogRule(this.key, this.pattern, this.level);

  /// Key of the plain-language explanation (`Strings.consoleExplain`).
  final String key;
  final String pattern;
  final LogLevel level;
}

class ClassifiedLine {
  const ClassifiedLine(this.text, this.level, this.ruleKey);

  final String text;
  final LogLevel level;
  final String? ruleKey;

  bool get isEvent => ruleKey != null;
}

abstract final class LogRules {
  static const rules = [
    LogRule('panic', r'panic\(|kernel panic', LogLevel.problem),
    LogRule('sensor', r'missing sensor', LogLevel.problem),
    LogRule('watchdog', r'watchdog', LogLevel.problem),
    LogRule('thermal', r'thermal|overheat|too hot', LogLevel.warning),
    LogRule(
      'memory',
      r'memorystatus|jetsam|memory pressure|low memory',
      LogLevel.warning,
    ),
    LogRule(
      'crash',
      r'crash|terminating app|exc_bad_access|exc_crash',
      LogLevel.warning,
    ),
    LogRule('smc', r'applesmc|\bsmc\b', LogLevel.info),
    LogRule('battery', r'battery|charger|charging', LogLevel.info),
    LogRule('usb', r'\busb\b|lightning|accessory', LogLevel.info),
  ];

  static final _compiled = [
    for (final r in rules) (r, RegExp(r.pattern, caseSensitive: false)),
  ];

  static ClassifiedLine classify(String line) {
    for (final (rule, re) in _compiled) {
      if (re.hasMatch(line)) return ClassifiedLine(line, rule.level, rule.key);
    }
    return ClassifiedLine(line, LogLevel.normal, null);
  }
}
