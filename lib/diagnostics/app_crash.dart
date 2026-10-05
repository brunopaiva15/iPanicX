import 'dart:convert';

import '../models/diagnostic_file.dart';
import 'panic_parser.dart';

/// Why an app stopped, in terms a technician can act on.
enum CrashCause {
  /// 0x8badf00d: the app froze too long (launch, resume, main thread).
  watchdog,

  /// 0xc00010ff: iOS stopped it because the iPhone was too hot.
  thermal,

  /// 0xdead10cc: kept a file/database lock while in the background.
  fileLock,

  /// EXC_BAD_ACCESS: invalid memory access.
  memoryAccess,

  /// EXC_CRASH / SIGABRT: the app aborted itself (uncaught exception…).
  abort,

  /// EXC_BREAKPOINT / SIGTRAP: Swift runtime check failed.
  swiftError,

  /// EXC_RESOURCE CPU / wakeups limit.
  cpuLimit,

  /// EXC_RESOURCE memory limit.
  memoryLimit,

  /// EXC_GUARD: misuse of a protected resource.
  guard,

  /// SIGKILL by the system (no more precise reason given).
  killed,
  other;

  /// Causes that can point at the iPhone rather than at the app.
  bool get canBeHardware =>
      this == CrashCause.thermal || this == CrashCause.memoryAccess;
}

/// One app crash report (`bug_type` 309, or legacy text 109).
class AppCrash {
  const AppCrash({
    required this.file,
    required this.app,
    required this.cause,
    this.bundleId,
    this.version,
    this.date,
    this.firstParty = false,
    this.exceptionType,
    this.signal,
    this.subtype,
    this.terminationNamespace,
    this.terminationCode,
    this.terminationReason,
    this.crashedIn,
  });

  final DiagnosticFile file;
  final String app;
  final String? bundleId;
  final String? version;
  final DateTime? date;

  /// Apple app or system process (`is_first_party`).
  final bool firstParty;
  final String? exceptionType;
  final String? signal;
  final String? subtype;
  final String? terminationNamespace;

  /// Hex, e.g. `0x8badf00d`.
  final String? terminationCode;
  final String? terminationReason;

  /// Top frame of the crashed thread (`image  symbol`).
  final String? crashedIn;
  final CrashCause cause;

  /// `EXC_BAD_ACCESS (SIGSEGV)`, `0x8badf00d`…
  String get technical => [
    if (exceptionType != null)
      signal == null ? exceptionType! : '$exceptionType ($signal)',
    if (terminationNamespace != null || terminationCode != null)
      [terminationNamespace, terminationCode].whereType<String>().join(' '),
  ].join(' · ');
}

abstract final class AppCrashParser {
  static AppCrash parse(DiagnosticFile file, String content) {
    final nl = content.indexOf('\n');
    final headerLine = (nl < 0 ? content : content.substring(0, nl)).trim();
    final body = nl < 0 ? '' : content.substring(nl + 1);
    Map<String, dynamic> header = const {};
    try {
      final h = jsonDecode(headerLine);
      if (h is Map<String, dynamic>) header = h;
    } catch (_) {}

    final app = (header['app_name'] ?? header['name'] ?? header['procname'])
        ?.toString()
        .trim();
    final date = PanicParser.parseDate(header['timestamp']?.toString());
    final base = _Fields(
      app: (app == null || app.isEmpty) ? _nameFromFile(file.name) : app,
      bundleId: header['bundleID']?.toString(),
      version: _nonEmpty(header['app_version']?.toString()),
      date: date ?? file.date,
      firstParty:
          header['is_first_party'] == 1 || header['is_first_party'] == true,
    );

    Map<String, dynamic>? json;
    try {
      final b = jsonDecode(body);
      if (b is Map<String, dynamic>) json = b;
    } catch (_) {}
    return json != null
        ? _fromJson(file, base, json)
        : _fromText(file, base, body);
  }

  static AppCrash _fromJson(
    DiagnosticFile file,
    _Fields f,
    Map<String, dynamic> j,
  ) {
    final ex = j['exception'];
    final term = j['termination'];
    String? s(Object? m, String k) =>
        m is Map ? _nonEmpty(m[k]?.toString()) : null;

    final code = term is Map ? _hex(term['code']) : null;
    String? reason;
    if (term is Map) {
      final reasons = term['reasons'];
      reason = reasons is List && reasons.isNotEmpty
          ? reasons.map((e) => e.toString()).join(' ')
          : _nonEmpty(term['indicator']?.toString());
    }
    final asi = j['asi'];
    if (reason == null && asi is Map && asi.isNotEmpty) {
      final v = asi.values.first;
      reason = v is List ? v.join(' ') : v.toString();
    }

    String? crashedIn;
    final threads = j['threads'], images = j['usedImages'];
    final fault = j['faultingThread'];
    if (threads is List && fault is int && fault < threads.length) {
      final thread = threads[fault];
      final frames = thread is Map ? thread['frames'] : null;
      if (frames is List && frames.isNotEmpty && frames.first is Map) {
        final fr = frames.first as Map;
        final idx = fr['imageIndex'];
        String? img;
        if (images is List && idx is int && idx < images.length) {
          final entry = images[idx];
          if (entry is Map) img = entry['name']?.toString();
        }
        crashedIn = [
          img,
          fr['symbol']?.toString(),
        ].whereType<String>().join('  ');
        if (crashedIn.isEmpty) crashedIn = null;
      }
    }
    final bundle = j['bundleInfo'];
    final type = s(ex, 'type');
    final signal = s(ex, 'signal');
    final subtype = s(ex, 'subtype');
    final ns = s(term, 'namespace');
    return AppCrash(
      file: file,
      app: f.app,
      bundleId: f.bundleId ?? s(bundle, 'CFBundleIdentifier'),
      version: f.version ?? s(bundle, 'CFBundleShortVersionString'),
      date: f.date,
      firstParty: f.firstParty,
      exceptionType: type,
      signal: signal,
      subtype: subtype,
      terminationNamespace: ns,
      terminationCode: code,
      terminationReason: reason,
      crashedIn: crashedIn,
      cause: classify(type, signal, subtype, code, reason),
    );
  }

  static final _exType = RegExp(
    r'^Exception Type:\s*(\S+)(?:\s*\((\w+)\))?',
    multiLine: true,
  );
  static final _exSub = RegExp(r'^Exception Subtype:\s*(.+)$', multiLine: true);
  static final _term = RegExp(r'^Termination Reason:\s*(.+)$', multiLine: true);
  static final _asi = RegExp(
    r'^Application Specific Information:\s*\n(.+)$',
    multiLine: true,
  );

  static AppCrash _fromText(DiagnosticFile file, _Fields f, String body) {
    final ex = _exType.firstMatch(body);
    final termLine = _term.firstMatch(body)?.group(1)?.trim();
    final ns = termLine == null
        ? null
        : RegExp(r'Namespace\s+(\w+)').firstMatch(termLine)?.group(1);
    final code = termLine == null
        ? null
        : RegExp(r'Code\s+(0x[0-9a-fA-F]+|\d+)').firstMatch(termLine)?.group(1);
    final reason = _asi.firstMatch(body)?.group(1)?.trim();
    final type = ex?.group(1), signal = ex?.group(2);
    final subtype = _exSub.firstMatch(body)?.group(1)?.trim();
    final hex = code == null ? null : _hex(code);
    return AppCrash(
      file: file,
      app: f.app,
      bundleId: f.bundleId,
      version: f.version,
      date: f.date,
      firstParty: f.firstParty,
      exceptionType: type,
      signal: signal,
      subtype: subtype,
      terminationNamespace: ns,
      terminationCode: hex,
      terminationReason: reason ?? termLine,
      cause: classify(type, signal, subtype, hex, reason ?? termLine),
    );
  }

  static CrashCause classify(
    String? type,
    String? signal,
    String? subtype,
    String? code,
    String? reason,
  ) {
    final c = code?.toLowerCase();
    if (c == '0x8badf00d') return CrashCause.watchdog;
    if (c == '0xc00010ff') return CrashCause.thermal;
    if (c == '0xdead10cc') return CrashCause.fileLock;
    final t = type?.toUpperCase() ?? '';
    final sub = '${subtype ?? ''} ${reason ?? ''}'.toUpperCase();
    if (t == 'EXC_RESOURCE') {
      if (sub.contains('MEMORY')) return CrashCause.memoryLimit;
      return CrashCause.cpuLimit;
    }
    if (t == 'EXC_BAD_ACCESS') return CrashCause.memoryAccess;
    if (t == 'EXC_BREAKPOINT' || signal == 'SIGTRAP') {
      return CrashCause.swiftError;
    }
    if (t == 'EXC_GUARD') return CrashCause.guard;
    if (signal == 'SIGABRT') return CrashCause.abort;
    if (signal == 'SIGKILL') return CrashCause.killed;
    if (signal == 'SIGSEGV' || signal == 'SIGBUS') {
      return CrashCause.memoryAccess;
    }
    return CrashCause.other;
  }

  static String? _hex(Object? v) {
    if (v == null) return null;
    if (v is int) return '0x${v.toUnsigned(64).toRadixString(16)}';
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    if (s.toLowerCase().startsWith('0x')) return s.toLowerCase();
    final n = int.tryParse(s);
    return n == null ? s : '0x${n.toUnsigned(64).toRadixString(16)}';
  }

  static String? _nonEmpty(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();

  /// `Instagram-2026-10-04-174233.ips` → `Instagram`.
  static String _nameFromFile(String name) {
    final m = RegExp(r'^(.+?)-\d{4}-\d{2}-\d{2}').firstMatch(name);
    return m?.group(1) ?? name;
  }
}

class _Fields {
  const _Fields({
    required this.app,
    this.bundleId,
    this.version,
    this.date,
    this.firstParty = false,
  });
  final String app;
  final String? bundleId;
  final String? version;
  final DateTime? date;
  final bool firstParty;
}

/// What the crashes of a period say as a whole.
enum CrashPattern {
  /// One app causes most crashes: an app problem, not the iPhone.
  oneApp,

  /// Many different apps (incl. Apple's) crash on memory errors.
  systemWide,

  /// Some apps were stopped because the iPhone was too hot.
  thermal,

  /// No dominant app or cause.
  spread,
}

class AppCrashGroup {
  AppCrashGroup(this.app, this.crashes);
  final String app;

  /// Newest first.
  final List<AppCrash> crashes;

  int get count => crashes.length;
  bool get firstParty => crashes.any((c) => c.firstParty);
  DateTime? get last => crashes.first.date;
  String? get bundleId => crashes.first.bundleId;

  /// Most frequent cause for this app.
  CrashCause get mainCause {
    final counts = <CrashCause, int>{};
    for (final c in crashes) {
      counts[c.cause] = (counts[c.cause] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
}

/// App crashes of a period, grouped by app and by cause.
class AppCrashSummary {
  AppCrashSummary(List<AppCrash> crashes)
    : crashes = [...crashes]..sort(_newestFirst) {
    final byApp = <String, List<AppCrash>>{};
    for (final c in this.crashes) {
      byApp.putIfAbsent(c.app, () => []).add(c);
    }
    apps = [for (final e in byApp.entries) AppCrashGroup(e.key, e.value)]
      ..sort((a, b) => b.count.compareTo(a.count));
    for (final c in this.crashes) {
      causes[c.cause] = (causes[c.cause] ?? 0) + 1;
    }
  }

  final List<AppCrash> crashes;
  late final List<AppCrashGroup> apps;
  final Map<CrashCause, int> causes = {};

  int get total => crashes.length;

  /// Crashes per day, oldest first, over the [days] before [now].
  List<int> perDay(DateTime now, int days) {
    final today = DateTime(now.year, now.month, now.day);
    final out = List<int>.filled(days, 0);
    for (final c in crashes) {
      final d = c.date;
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      final i = days - 1 - today.difference(day).inDays;
      if (i >= 0 && i < days) out[i]++;
    }
    return out;
  }

  CrashPattern? get pattern {
    if (total == 0) return null;
    if ((causes[CrashCause.thermal] ?? 0) > 0) return CrashPattern.thermal;
    final memoryApps = apps
        .where((a) => a.crashes.any((c) => c.cause == CrashCause.memoryAccess))
        .toList();
    if (total >= 10 &&
        memoryApps.length >= 4 &&
        memoryApps.where((a) => a.firstParty).length >= 2) {
      return CrashPattern.systemWide;
    }
    if (apps.first.count / total >= 0.6) return CrashPattern.oneApp;
    return CrashPattern.spread;
  }

  static int _newestFirst(AppCrash a, AppCrash b) {
    final da = a.date, db = b.date;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }
}
