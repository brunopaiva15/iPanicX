import '../l10n/strings.dart';

/// Structured data extracted from a `panic-full*.ips` file.
///
/// Every field is optional: the parser never throws on a missing field.
class PanicReport {
  const PanicReport({
    required this.rawContent,
    this.timestamp,
    this.product,
    this.modelCode,
    this.osVersion,
    this.build,
    this.bugType,
    this.panicString,
    this.panicInitiator,
    this.socId,
    this.incident,
    this.sensorMask,
    this.kernelVersion,
    this.panicFlags,
    this.panickedProcess,
    this.backtraceKexts = const [],
    this.missingSensors = const [],
    this.sensorKeys = const [],
    this.parseWarnings = const [],
  });

  final DateTime? timestamp;

  /// Product type, e.g. `iPhone15,2`.
  final String? product;

  /// Hardware model code if present (e.g. `D73AP`).
  final String? modelCode;

  /// iOS version, e.g. `26.0`.
  final String? osVersion;

  /// iOS build, e.g. `23A341`.
  final String? build;

  /// `bug_type` from the IPS header (`210` for full kernel panics).
  final String? bugType;
  final String? panicString;
  final String? panicInitiator;
  final String? socId;
  final String? incident;

  /// Sensor bit mask reported by an SMC panic (`sensor array`), if any.
  final int? sensorMask;

  /// `Darwin Kernel Version …` (JSON `kernel` key or text line).
  final String? kernelVersion;
  final String? panicFlags;

  /// Process named in `Panicked task …: pid N: <name>`.
  final String? panickedProcess;

  /// Bundle ids listed under `Kernel Extensions in backtrace:`.
  final List<String> backtraceKexts;

  /// Sensors listed after `Missing sensor(s):`.
  final List<String> missingSensors;

  /// Four-character SMC keys found in the panic line (e.g. `TAOP`, `TAOJ`).
  final List<String> sensorKeys;

  /// Non-fatal parse problems (invalid JSON, truncated file…).
  final List<String> parseWarnings;

  final String rawContent;

  /// `bug_type` 210 identifies a kernel panic report (full or base).
  bool get isFullPanic => bugType == null || bugType == '210';

  /// `bug_type` 151: forced restart (`forceReset-*`, e.g. `btn_rst`).
  bool get isForcedReset => bugType == '151';

  /// Kernel-level report iPaniX can analyse (panic or forced reset).
  bool get isKernelReport => isFullPanic || isForcedReset;

  /// Human label for [bugType] (only types observed in real reports).
  String get reportKind => describeBugType(bugType);

  static String describeBugType(String? bugType) => tr.bugTypeLabel(bugType);

  bool get hasPanicString =>
      panicString != null && panicString!.trim().isNotEmpty;

  /// `0x140000` style representation of [sensorMask].
  String? get sensorMaskHex =>
      sensorMask == null ? null : formatHex(sensorMask!);

  static String formatHex(int value) =>
      '0x${value.toRadixString(16).toUpperCase()}';

  /// The `panic(cpu N caller 0x…): …` line. Some reports start with a
  /// preamble (`Attempting to forcibly halt cpu 2`…) before it; without a
  /// `panic(` line the first non-empty line is used.
  String? get panicLine => panicLineOf(panicString);

  static String? panicLineOf(String? panicString) {
    if (panicString == null) return null;
    final lines = panicString
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    return lines.firstWhere(
      (l) => l.startsWith('panic('),
      orElse: () => lines.first,
    );
  }

  /// [panicLine] without the `panic(cpu N caller 0x…):` prefix, used for
  /// display and grouping.
  String? get headline {
    var line = panicLine;
    if (line == null) return null;
    line = line.replaceFirst(
      RegExp(r'^panic\(cpu \d+ caller 0x[0-9a-fA-F]+\):\s*'),
      '',
    );
    if (line.isEmpty) return panicLine;
    if (line.length > 160) line = '${line.substring(0, 157)}…';
    return line;
  }

  /// [headline] with addresses and numbers removed so that the same panic
  /// signature groups together across occurrences.
  String? get signature {
    final h = headline;
    if (h == null) return null;
    return h
        .replaceAll(RegExp(r'0x[0-9a-fA-F]+'), '0x…')
        .replaceAll(RegExp(r'@[\w./-]+:\d+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
