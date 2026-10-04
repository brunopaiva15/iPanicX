import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../diagnostics/knowledge_base.dart';
import '../diagnostics/panic_analyzer.dart';
import '../diagnostics/panic_parser.dart';
import '../models/diagnostic_file.dart';
import '../models/panic_report.dart';
import '../models/scan_result.dart';
import 'iphone_service.dart';

/// Pulls reports from the device, then parses and analyses every
/// `panic-full` file. Everything stays on the Mac.
class DiagnosticService {
  DiagnosticService({
    required this.iphone,
    required this.knowledgeBase,
    this.useIsolate = true,
  });

  final IPhoneService iphone;
  final KnowledgeBase knowledgeBase;

  /// Parse in a background isolate so large reports don't block the UI.
  final bool useIsolate;

  PanicAnalyzer get analyzer => PanicAnalyzer(knowledgeBase);

  Future<ScanResult> scan({
    CrashReportProgress? onProgress,
    void Function()? onAnalyzing,
  }) async {
    final files = await iphone.getCrashReports(onProgress: onProgress);
    onAnalyzing?.call();
    // panic-full first so they win the incident de-duplication below.
    final kernelFiles = files.where((f) => f.isKernelReport).toList()
      ..sort((a, b) {
        final pa = a.isPanicFull ? 0 : 1, pb = b.isPanicFull ? 0 : 1;
        return pa != pb ? pa - pb : DiagnosticFile.newestFirst(a, b);
      });

    final contents = <(DiagnosticFile, String)>[];
    final unreadable = <DiagnosticFile>[];
    for (final f in kernelFiles) {
      try {
        contents.add((f, await iphone.readCrashReport(f)));
      } on IPhoneServiceException {
        unreadable.add(f);
      }
    }

    final analysed = useIsolate
        ? await _analyzeInIsolate(knowledgeBase, contents)
        : _analyzeAll(knowledgeBase, contents);

    // The same incident is often written as both panic-full and panic-base.
    final seenIncidents = <String>{};
    final panics = <AnalyzedPanic>[];
    final forcedResets = <AnalyzedPanic>[];
    for (final a in analysed) {
      final incident = a.report.incident;
      if (incident != null && !seenIncidents.add(incident)) continue;
      if (a.report.isForcedReset ||
          a.file.type == DiagnosticFileType.forceReset) {
        forcedResets.add(a);
      } else if (a.report.isFullPanic) {
        panics.add(a);
      }
    }
    panics.sort(_newestFirst);
    forcedResets.sort(_newestFirst);

    return ScanResult(
      directory: files.isEmpty ? '' : _commonRoot(files),
      files: files,
      panics: panics,
      forcedResets: forcedResets,
      health: DeviceHealthSummary.fromPanics(
        panics,
        forcedResetCount: forcedResets.length,
      ),
      unreadable: unreadable,
      scannedAt: DateTime.now(),
    );
  }

  /// Analyses a `.ips` file chosen manually on the Mac.
  Future<AnalyzedPanic> analyzeLocalFile(String path) async {
    final file = File(path);
    final stat = await file.stat();
    final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final entry = DiagnosticFile.fromPath(
      path: path,
      rootDirectory: file.parent.path,
      sizeBytes: stat.size,
      modified: stat.modified,
    );
    return analyzeContent(knowledgeBase, entry, content);
  }

  static int _newestFirst(AnalyzedPanic a, AnalyzedPanic b) {
    final da = a.date, db = b.date;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  // Kept static so the isolate closure only captures sendable data.
  static Future<List<AnalyzedPanic>> _analyzeInIsolate(
    KnowledgeBase kb,
    List<(DiagnosticFile, String)> contents,
  ) => Isolate.run(() => _analyzeAll(kb, contents));

  static List<AnalyzedPanic> _analyzeAll(
    KnowledgeBase kb,
    List<(DiagnosticFile, String)> contents,
  ) => [
    for (final (file, content) in contents) analyzeContent(kb, file, content),
  ];

  static AnalyzedPanic analyzeContent(
    KnowledgeBase kb,
    DiagnosticFile file,
    String content,
  ) {
    final PanicReport report = const PanicParser().parse(content);
    return AnalyzedPanic(
      file: file,
      report: report,
      result: PanicAnalyzer(kb).analyze(report),
    );
  }

  static String _commonRoot(List<DiagnosticFile> files) {
    final f = files.first;
    final p = f.path.replaceAll('\\', '/');
    return p
        .substring(0, p.length - f.relativePath.length)
        .replaceFirst(RegExp(r'/$'), '');
  }
}
