import '../l10n/strings.dart';
import 'diagnostic_file.dart';
import 'diagnostic_result.dart';
import 'panic_report.dart';

/// One parsed + analysed panic file.
class AnalyzedPanic {
  const AnalyzedPanic({
    required this.file,
    required this.report,
    required this.result,
  });

  final DiagnosticFile file;
  final PanicReport report;
  final DiagnosticResult result;

  /// Best available date: panic timestamp, else file-name date.
  DateTime? get date => report.timestamp ?? file.date;
}

enum HealthVerdict {
  noPanics,
  hardwareIssueLikely,
  undetermined;

  String get label => tr.verdictLabel(name);
}

/// Factual summary of the device's panic history. Deliberately no score.
class DeviceHealthSummary {
  const DeviceHealthSummary({
    required this.panicCount,
    required this.verdict,
    this.mostCommonPanic,
    this.mostCommonCount = 0,
    this.latest,
    this.forcedResetCount = 0,
  });

  final int panicCount;
  final String? mostCommonPanic;
  final int mostCommonCount;
  final DateTime? latest;
  final HealthVerdict verdict;

  /// User-initiated forced restarts; informational only.
  final int forcedResetCount;

  static DeviceHealthSummary fromPanics(
    List<AnalyzedPanic> panics, {
    int forcedResetCount = 0,
  }) {
    if (panics.isEmpty) {
      return DeviceHealthSummary(
        panicCount: 0,
        verdict: HealthVerdict.noPanics,
        forcedResetCount: forcedResetCount,
      );
    }
    final counts = <String, int>{};
    for (final p in panics) {
      final key = p.result.isKnownSignature
          ? p.result.title
          : (p.report.signature ?? p.result.title);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    DateTime? latest;
    for (final p in panics) {
      final d = p.date;
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    final hardware = panics.any(
      (p) =>
          p.result.isHardwareRelated &&
          p.result.confidence.rank >= Confidence.medium.rank,
    );
    return DeviceHealthSummary(
      panicCount: panics.length,
      mostCommonPanic: top.key,
      mostCommonCount: top.value,
      latest: latest,
      forcedResetCount: forcedResetCount,
      verdict: hardware
          ? HealthVerdict.hardwareIssueLikely
          : HealthVerdict.undetermined,
    );
  }
}

/// First line (IPS header) of a report that is not a kernel panic: enough
/// to count app crashes, Jetsam events and reset counters without parsing
/// megabytes of JSON.
class ReportHeader {
  const ReportHeader({
    required this.file,
    this.bugType,
    this.timestamp,
    this.name,
  });

  final DiagnosticFile file;
  final String? bugType;
  final DateTime? timestamp;

  /// App or process name (`app_name` / `name`), when present.
  final String? name;

  DateTime? get date => timestamp ?? file.date;

  bool get isAppCrash => bugType == '309' || bugType == '109';
  bool get isJetsam =>
      file.type == DiagnosticFileType.jetsamEvent || bugType == '298';
  bool get isResetCounter =>
      file.type == DiagnosticFileType.resetCounter || bugType == '115';
}

/// Output of a full "Scan Diagnostics" run.
class ScanResult {
  const ScanResult({
    required this.directory,
    required this.files,
    required this.panics,
    this.forcedResets = const [],
    required this.health,
    this.unreadable = const [],
    required this.scannedAt,
    this.reports = const [],
  });

  /// Local folder where crash reports were copied.
  final String directory;

  /// All copied files, newest first.
  final List<DiagnosticFile> files;

  /// Analysed kernel panics (panic-full, plus panic-base reports whose
  /// incident has no panic-full copy), newest first.
  final List<AnalyzedPanic> panics;

  /// Forced restarts (`forceReset-*`, bug_type 151), newest first. These are
  /// user-initiated (buttons held) and are not counted as kernel panics.
  final List<AnalyzedPanic> forcedResets;
  final DeviceHealthSummary health;

  /// panic-full files that could not be read from disk.
  final List<DiagnosticFile> unreadable;
  final DateTime scannedAt;

  /// Headers of the other reports (app crashes, Jetsam, reset counters…).
  final List<ReportHeader> reports;

  /// App crashes in the [days] before [now] (default: the scan date).
  List<ReportHeader> appCrashes({int days = 7, DateTime? now}) =>
      _recent(reports.where((r) => r.isAppCrash), days, now);

  List<ReportHeader> jetsamEvents({int days = 7, DateTime? now}) =>
      _recent(reports.where((r) => r.isJetsam), days, now);

  List<ReportHeader> _recent(
    Iterable<ReportHeader> list,
    int days,
    DateTime? now,
  ) {
    final from = (now ?? scannedAt).subtract(Duration(days: days));
    return [
      for (final r in list)
        if (r.date != null && r.date!.isAfter(from)) r,
    ];
  }

  AnalyzedPanic? get latestPanic => panics.isEmpty ? null : panics.first;

  int countOf(DiagnosticFileType type) =>
      files.where((f) => f.type == type).length;
}
