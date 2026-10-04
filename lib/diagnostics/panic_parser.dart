import 'dart:convert';

import '../models/panic_report.dart';

/// Parses `panic-full*.ips` files.
///
/// Supported layouts:
///  * a single JSON document;
///  * the modern IPS layout: a one-line JSON header followed by a JSON body;
///  * JSON followed by free text;
///  * partially invalid / truncated JSON (falls back to key extraction);
///  * semi-structured `key: value` text.
///
/// [parse] never throws; problems are reported in
/// [PanicReport.parseWarnings].
class PanicParser {
  const PanicParser();

  PanicReport parse(String content) {
    final warnings = <String>[];
    final text = content.startsWith('﻿') ? content.substring(1) : content;

    final chunks = _extractJsonChunks(text);
    final objects = <Map<String, dynamic>>[];
    final brokenChunks = <String>[];
    for (final chunk in chunks) {
      try {
        final decoded = jsonDecode(chunk);
        if (decoded is Map<String, dynamic>) objects.add(decoded);
      } on FormatException {
        brokenChunks.add(chunk);
      }
    }
    if (chunks.isEmpty) {
      warnings.add('No JSON content found; parsed as plain text.');
    }
    if (brokenChunks.isNotEmpty) {
      warnings.add(
        '${brokenChunks.length} JSON section(s) are invalid or truncated; '
        'fields were extracted on a best-effort basis.',
      );
    }

    // Header first, body afterwards: later objects take precedence, except
    // for header-only keys.
    final fields = <String, dynamic>{};
    for (final obj in objects) {
      fields.addAll(obj);
    }
    for (final chunk in brokenChunks) {
      _lenientFields(chunk).forEach((k, v) => fields.putIfAbsent(k, () => v));
    }
    _lineFields(text).forEach((k, v) => fields.putIfAbsent(k, () => v));

    String? str(List<String> keys) {
      for (final k in keys) {
        final v = fields[k];
        if (v == null) continue;
        final s = v is String ? v.trim() : v.toString();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    // Header keys that the body may override with a different meaning.
    final header = objects.isNotEmpty ? objects.first : const {};

    // `string` holds the panic text of forced-reset reports (bug_type 151).
    var panicString = str(['panicString', 'panic_string', 'panic', 'string']);
    panicString ??= _plainTextPanic(text);
    if (panicString == null) {
      warnings.add('No panic string found.');
    }

    // OS / build: "iPhone OS 26.0 (23A341)".
    String? osVersion;
    String? build;
    for (final raw in [
      str(['os_version']),
      header['os_version']?.toString(),
      str(['build', 'osVersion']),
    ]) {
      if (raw == null) continue;
      final m = RegExp(
        r'(?:iPhone OS|iOS|iPadOS)?\s*(\d+(?:\.\d+)*)\s*\(([0-9A-Za-z]+)\)',
      ).firstMatch(raw);
      if (m != null) {
        osVersion ??= m.group(1);
        build ??= m.group(2);
      } else if (RegExp(r'^\d+[A-Z]\d+[a-z]?$').hasMatch(raw)) {
        build ??= raw;
      } else if (RegExp(r'^\d+(\.\d+)+$').hasMatch(raw)) {
        osVersion ??= raw;
      }
    }

    var product = str(['product', 'productType', 'modelCode']);
    product ??= RegExp(r'\b(iPhone\d+,\d+|iPad\d+,\d+)\b')
        .firstMatch(text)
        ?.group(1);

    final timestamp =
        _parseDate(str(['timestamp'])) ??
        _parseDate(header['timestamp']?.toString()) ??
        _parseDate(str(['date', 'captureTime']));

    final bugType = str(['bug_type', 'bugType']);
    if (bugType != null && bugType != '210' && bugType != '151') {
      warnings.add(
        'bug_type $bugType is not a full kernel panic report (expected 210): '
        '${PanicReport.describeBugType(bugType)}.',
      );
    }

    // Only scan the whole file when it is not structured JSON, to avoid
    // matching strings inside binaryImages / processByPid.
    final freeText = objects.isEmpty ? text : null;
    final sensorMask = _sensorMask(fields, panicString, freeText);
    final missing = _missingSensors(panicString ?? freeText ?? '');

    return PanicReport(
      rawContent: content,
      timestamp: timestamp,
      product: product,
      modelCode: str(['modelCode', 'model', 'hardwareModel']),
      osVersion: osVersion,
      build: build,
      bugType: bugType,
      panicString: panicString,
      panicInitiator:
          str(['panicInitiator', 'panic_initiator']) ??
          _panicInitiator(panicString),
      socId: str(['socId', 'soc_id']),
      incident: str(['incident', 'incident_id']),
      sensorMask: sensorMask,
      kernelVersion: str(['kernel', 'kernelVersion']),
      panicFlags: str(['panicFlags', 'panic_flags']),
      panickedProcess: _panickedProcess(panicString),
      backtraceKexts: _backtraceKexts(panicString),
      missingSensors: missing,
      sensorKeys: _sensorKeys(panicString),
      parseWarnings: warnings,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON chunking

  /// Splits [text] into top-level `{…}` chunks. An unterminated chunk (e.g. a
  /// truncated file) is returned as-is so lenient extraction can still run.
  static List<String> _extractJsonChunks(String text) {
    final chunks = <String>[];
    var i = 0;
    while (i < text.length) {
      final start = text.indexOf('{', i);
      if (start < 0) break;
      // Only consider braces that start a line (or the file) to avoid
      // picking up `{` inside free text.
      if (start > 0) {
        final before = text.substring(
          text.lastIndexOf('\n', start - 1) + 1,
          start,
        );
        if (before.trim().isNotEmpty) {
          i = start + 1;
          continue;
        }
      }
      var depth = 0;
      var inString = false;
      var escaped = false;
      var end = -1;
      for (var j = start; j < text.length; j++) {
        final c = text.codeUnitAt(j);
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (c == 0x5C) {
            escaped = true;
          } else if (c == 0x22) {
            inString = false;
          }
          continue;
        }
        if (c == 0x22) {
          inString = true;
        } else if (c == 0x7B) {
          depth++;
        } else if (c == 0x7D) {
          depth--;
          if (depth == 0) {
            end = j;
            break;
          }
        }
      }
      if (end < 0) {
        chunks.add(text.substring(start));
        break;
      }
      chunks.add(text.substring(start, end + 1));
      i = end + 1;
    }
    return chunks;
  }

  static final RegExp _kvPattern = RegExp(
    r'"([A-Za-z_][A-Za-z0-9_ ]*)"\s*:\s*("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?|true|false|null)',
  );

  /// Best-effort extraction of scalar `"key": value` pairs from broken JSON.
  static Map<String, dynamic> _lenientFields(String chunk) {
    final out = <String, dynamic>{};
    for (final m in _kvPattern.allMatches(chunk)) {
      final key = m.group(1)!;
      final raw = m.group(2)!;
      dynamic value;
      try {
        value = jsonDecode(raw);
      } on FormatException {
        value = raw.startsWith('"')
            ? _unescape(raw.substring(1, raw.length - 1))
            : raw;
      }
      out.putIfAbsent(key, () => value);
    }
    // A truncated panicString has no closing quote: take the rest.
    if (!out.containsKey('panicString')) {
      final m = RegExp(r'"panicString"\s*:\s*"').firstMatch(chunk);
      if (m != null) {
        final rest = chunk.substring(m.end);
        final close = RegExp(r'(?<!\\)"').firstMatch(rest);
        out['panicString'] = _unescape(
          close == null ? rest : rest.substring(0, close.start),
        );
      }
    }
    return out;
  }

  static String _unescape(String s) => s
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r'\r', '')
      .replaceAll(r'\"', '"')
      .replaceAll(r'\/', '/')
      .replaceAll(r'\\', '\\');

  static const _lineKeys = {
    'product': 'product',
    'producttype': 'product',
    'hardware model': 'product',
    'kernel version': 'kernel',
    'panic flags': 'panicFlags',
    'model': 'modelCode',
    'modelcode': 'modelCode',
    'os version': 'os_version',
    'os_version': 'os_version',
    'build': 'build',
    'bug_type': 'bug_type',
    'bug type': 'bug_type',
    'incident': 'incident',
    'incident identifier': 'incident',
    'socid': 'socId',
    'soc id': 'socId',
    'date/time': 'date',
    'date': 'date',
    'timestamp': 'timestamp',
    'panic initiator': 'panicInitiator',
    'sensor array': 'sensorArray',
    'sensor mask': 'sensorMask',
  };

  /// `Key: value` lines (semi-structured / legacy text reports).
  static Map<String, dynamic> _lineFields(String text) {
    final out = <String, dynamic>{};
    final re = RegExp(
      r'^\s*([A-Za-z][A-Za-z _/]{1,30}?)\s*:\s*(.+?)\s*$',
      multiLine: true,
    );
    for (final m in re.allMatches(text)) {
      final key = _lineKeys[m.group(1)!.toLowerCase()];
      if (key == null) continue;
      out.putIfAbsent(key, () => m.group(2)!);
    }
    return out;
  }

  /// Raw `panic(cpu …` block in a plain-text report.
  static String? _plainTextPanic(String text) {
    final start = text.indexOf(RegExp(r'panic\(cpu'));
    if (start < 0) return null;
    // Legacy text reports: keep backtrace and kext sections too.
    var end = text.length;
    final json = text.indexOf(RegExp(r'^\s*\{', multiLine: true), start);
    if (json > start) end = json;
    if (end - start > 64 * 1024) end = start + 64 * 1024;
    final s = text.substring(start, end);
    // Strip a trailing quote/brace if we cut through JSON.
    return s.replaceFirst(RegExp(r'["\s,}]+$'), '');
  }

  // ---------------------------------------------------------------------------
  // Field helpers

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final m = RegExp(
      r'(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?\s*(Z|[+-]\d{2}:?\d{2})?',
    ).firstMatch(raw);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    final s = int.parse(m.group(6)!);
    final frac = m.group(7);
    final ms = frac == null
        ? 0
        : int.parse(frac.padRight(3, '0').substring(0, 3));
    final tz = m.group(8);
    if (tz == null) return DateTime(y, mo, d, h, mi, s, ms);
    var utc = DateTime.utc(y, mo, d, h, mi, s, ms);
    if (tz != 'Z') {
      final sign = tz.startsWith('-') ? -1 : 1;
      final digits = tz.substring(1).replaceAll(':', '');
      final offset = Duration(
        hours: int.parse(digits.substring(0, 2)),
        minutes: int.parse(digits.substring(2, 4)),
      );
      utc = utc.subtract(offset * sign);
    }
    return utc.toLocal();
  }

  static int? _parseInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s.toLowerCase().startsWith('0x')) {
      return int.tryParse(s.substring(2), radix: 16);
    }
    return int.tryParse(s);
  }

  static final RegExp _maskInText = RegExp(
    r'sensor[\s_-]*(?:array|mask|bitmap|bits)\s*[:=]?\s*\(?\s*(0x[0-9a-fA-F]+|\d+)',
    caseSensitive: false,
  );

  /// Sensor mask from a dedicated JSON key, or from the panic text
  /// (`sensor array 1310720`, `sensor mask: 0x140000`, …).
  static int? _sensorMask(
    Map<String, dynamic> fields,
    String? panicString,
    String? text,
  ) {
    for (final key in [
      'sensorMask',
      'sensor_mask',
      'sensorArray',
      'sensor_array',
      'sensor array',
      'sensor mask',
    ]) {
      final v = _parseInt(fields[key]);
      if (v != null) return v;
    }
    for (final source in [panicString, text]) {
      if (source == null) continue;
      final m = _maskInText.firstMatch(source);
      if (m != null) return _parseInt(m.group(1));
    }
    return null;
  }

  static List<String> _missingSensors(String text) {
    final m = RegExp(
      r'Missing sensor\(s\)\s*:\s*([^\n"]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return const [];
    return m
        .group(1)!
        .split(RegExp(r'[\s,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static const _notSensorKeys = {
    'SMC',
    'BSC',
    'PANIC',
    'FAIL',
    'CODE',
    'DATA',
    'TASK',
    'NULL',
    'INFO',
    'MODE',
    'TRUE',
    'UUID',
    'TIME',
    'SPMI',
    'PMGR',
    'ANS2',
    'DART',
    'ARM6',
  };

  /// Four-character SMC keys (TAOP, TAOJ, TG0B…) mentioned at the top of an
  /// SMC panic (first paragraph only, never in backtraces).
  static List<String> _sensorKeys(String? panicString) {
    if (panicString == null || !panicString.contains('SMC')) return const [];
    // Start at the `panic(` line (skips preambles such as CPU halt notes).
    final start = panicString.indexOf('panic(');
    final head = panicString
        .substring(start < 0 ? 0 : start)
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .first
        .split(RegExp(r'\r?\n'))
        .take(5)
        .join('\n');
    final keys = <String>[];
    for (final m in RegExp(r'\b([A-Z][A-Z0-9]{3})\b').allMatches(head)) {
      final k = m.group(1)!;
      if (_notSensorKeys.contains(k) || keys.contains(k)) continue;
      keys.add(k);
    }
    return keys;
  }

  static final RegExp _panickedTask = RegExp(
    r'Panicked task 0x[0-9a-fA-F]+:.*?pid -?\d+:\s*([^\n]+)',
  );

  static String? _panickedProcess(String? panicString) {
    if (panicString == null) return null;
    return _panickedTask.firstMatch(panicString)?.group(1)!.trim();
  }

  /// `com.apple.driver.AppleSMC(1.0)[UUID]@0x…` lines in the
  /// "Kernel Extensions in backtrace" section.
  static List<String> _backtraceKexts(String? panicString) {
    if (panicString == null) return const [];
    final start = panicString.indexOf(
      RegExp('Kernel Extensions in backtrace', caseSensitive: false),
    );
    if (start < 0) return const [];
    var section = panicString.substring(start);
    final end = section.indexOf(RegExp(r'\n\s*\n'));
    if (end > 0) section = section.substring(0, end);
    final kexts = <String>[];
    for (final m in RegExp(
      r'(?:dependency:\s*)?(com\.[\w.\-]+)\(',
    ).allMatches(section)) {
      if (m.group(0)!.startsWith('dependency')) continue;
      final id = m.group(1)!;
      if (!kexts.contains(id)) kexts.add(id);
    }
    return kexts;
  }

  static String? _panicInitiator(String? panicString) {
    if (panicString == null) return null;
    final by = RegExp(
      r'initiated by:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(panicString);
    if (by != null) return by.group(1)!.trim();
    // Coprocessor / subsystem named in the panic line (`SMC PANIC`, …).
    final firstLine = PanicReport.panicLineOf(panicString) ?? '';
    final tag = RegExp(r'\b(SMC|AOP|ANS2?|DCP|SEP|PMGR|SPMI)\b')
        .firstMatch(firstLine);
    if (tag != null) return tag.group(1);
    if (firstLine.contains('watchdog')) return 'watchdog';
    return _panickedProcess(panicString);
  }
}
