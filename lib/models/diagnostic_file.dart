import '../l10n/strings.dart';

enum DiagnosticFileType {
  panicFull,
  panicBase,
  jetsamEvent,
  forceReset,
  resetCounter,
  stacks,
  other;

  String get label => tr.fileTypeLabel(name);
}

/// A diagnostic/crash file copied from the iPhone to this computer.
class DiagnosticFile {
  const DiagnosticFile({
    required this.name,
    required this.path,
    required this.relativePath,
    required this.type,
    this.sizeBytes = 0,
    this.date,
  });

  /// Builds a file entry, deriving [type] and [date] from the file name.
  factory DiagnosticFile.fromPath({
    required String path,
    required String rootDirectory,
    int sizeBytes = 0,
    DateTime? modified,
  }) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    var relative = normalized;
    final root = rootDirectory.replaceAll('\\', '/');
    if (relative.startsWith(root)) {
      relative = relative.substring(root.length);
      while (relative.startsWith('/')) {
        relative = relative.substring(1);
      }
    }
    return DiagnosticFile(
      name: name,
      path: path,
      relativePath: relative,
      type: classify(name),
      sizeBytes: sizeBytes,
      date: dateFromFileName(name) ?? modified,
    );
  }

  final String name;

  /// Absolute local path.
  final String path;

  /// Path relative to the crash report root (e.g. `Retired/panic-full-…`).
  final String relativePath;
  final DiagnosticFileType type;
  final int sizeBytes;
  final DateTime? date;

  bool get isPanicFull => type == DiagnosticFileType.panicFull;

  /// Kernel-level reports parsed by the scan: panic-full, panic-base
  /// (incl. `+socd`) and forced-reset reports.
  bool get isKernelReport =>
      type == DiagnosticFileType.panicFull ||
      type == DiagnosticFileType.panicBase ||
      type == DiagnosticFileType.forceReset;

  static DiagnosticFileType classify(String fileName) {
    final n = fileName.toLowerCase();
    if (n.startsWith('panic-full')) return DiagnosticFileType.panicFull;
    if (n.startsWith('panic-base')) return DiagnosticFileType.panicBase;
    if (n.startsWith('jetsamevent')) return DiagnosticFileType.jetsamEvent;
    if (n.startsWith('forcereset')) return DiagnosticFileType.forceReset;
    if (n.startsWith('resetcounter')) return DiagnosticFileType.resetCounter;
    if (n.startsWith('stacks')) return DiagnosticFileType.stacks;
    return DiagnosticFileType.other;
  }

  static final RegExp _nameDate = RegExp(
    r'(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})',
  );

  /// Parses `panic-full-2026-10-04-174233.0002.ips` → 2026-10-04 17:42:33
  /// (device local time, interpreted as local time).
  static DateTime? dateFromFileName(String fileName) {
    final m = _nameDate.firstMatch(fileName);
    if (m == null) return null;
    final p = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    if (p[1] < 1 || p[1] > 12 || p[2] < 1 || p[2] > 31) return null;
    return DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
  }

  /// Most recent first; undated files last.
  static int newestFirst(DiagnosticFile a, DiagnosticFile b) {
    if (a.date == null && b.date == null) return b.name.compareTo(a.name);
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    return b.date!.compareTo(a.date!);
  }

  @override
  String toString() => 'DiagnosticFile($relativePath)';
}
