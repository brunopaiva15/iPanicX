import 'dart:convert';
import 'dart:io';

import '../app/host_platform.dart';

/// Short summary of one scan, kept locally to compare scans of a device.
/// No report content and no UDID is stored.
class HistoryEntry {
  const HistoryEntry({
    required this.date,
    required this.panics,
    this.productType,
    this.iosVersion,
    this.hardwareLikely = false,
    this.mainIssue,
    this.batteryHealth,
    this.cycleCount,
    this.storageUsedPercent,
    this.appCrashes7d,
    this.jetsam7d,
  });

  final DateTime date;
  final int panics;
  final String? productType;
  final String? iosVersion;
  final bool hardwareLikely;
  final String? mainIssue;
  final int? batteryHealth;
  final int? cycleCount;
  final int? storageUsedPercent;
  final int? appCrashes7d;
  final int? jetsam7d;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'panics': panics,
    'productType': productType,
    'iosVersion': iosVersion,
    'hardwareLikely': hardwareLikely,
    'mainIssue': mainIssue,
    'batteryHealth': batteryHealth,
    'cycleCount': cycleCount,
    'storageUsedPercent': storageUsedPercent,
    'appCrashes7d': appCrashes7d,
    'jetsam7d': jetsam7d,
  };

  static HistoryEntry? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final date = DateTime.tryParse('${j['date']}');
    final panics = j['panics'];
    if (date == null || panics is! int) return null;
    int? i(String k) => j[k] is int ? j[k] as int : null;
    return HistoryEntry(
      date: date,
      panics: panics,
      productType: j['productType'] as String?,
      iosVersion: j['iosVersion'] as String?,
      hardwareLikely: j['hardwareLikely'] == true,
      mainIssue: j['mainIssue'] as String?,
      batteryHealth: i('batteryHealth'),
      cycleCount: i('cycleCount'),
      storageUsedPercent: i('storageUsedPercent'),
      appCrashes7d: i('appCrashes7d'),
      jetsam7d: i('jetsam7d'),
    );
  }
}

/// One JSON file per device, named by a hash of its UDID, in the app's
/// support folder:
///  * macOS: `~/Library/Application Support/iPanicX/history`
///  * Windows: `%APPDATA%\iPanicX\history`
///  * elsewhere: `~/.ipanicx/history`
class HistoryStore {
  HistoryStore({Directory? root, Map<String, String>? environment})
    : _root = root ?? _defaultRoot(environment ?? Platform.environment);

  final Directory _root;

  /// Kept per device; older entries are dropped.
  static const maxEntries = 50;

  Directory get directory => _root;

  static Directory _defaultRoot(Map<String, String> env) {
    if (HostPlatform.isWindows) {
      final appData = env['APPDATA'] ?? env['LOCALAPPDATA'] ?? '.';
      return Directory('$appData/iPanicX/history');
    }
    final home = env['HOME'] ?? '.';
    if (Platform.isMacOS) {
      return Directory('$home/Library/Application Support/iPanicX/history');
    }
    return Directory('$home/.ipanicx/history');
  }

  /// FNV-1a 64-bit: stable, not reversible to the UDID from the file name.
  static String deviceKey(String udid) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(udid.toUpperCase())) {
      h ^= b;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    String hex32(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return hex32(h >> 32) + hex32(h);
  }

  File _file(String udid) => File('${_root.path}/${deviceKey(udid)}.json');

  /// Oldest first. Never throws.
  Future<List<HistoryEntry>> load(String udid) async {
    try {
      final f = _file(udid);
      if (!await f.exists()) return const [];
      final j = jsonDecode(await f.readAsString());
      if (j is! List) return const [];
      return [for (final e in j) ?HistoryEntry.fromJson(e)];
    } catch (_) {
      return const [];
    }
  }

  /// Appends [entry]; returns false if it could not be written.
  Future<bool> add(String udid, HistoryEntry entry) async {
    try {
      final list = [...await load(udid), entry];
      final kept = list.length > maxEntries
          ? list.sublist(list.length - maxEntries)
          : list;
      await _root.create(recursive: true);
      await _file(
        udid,
      ).writeAsString(jsonEncode([for (final e in kept) e.toJson()]));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Number of saved scans, all devices.
  Future<int> count() async {
    try {
      if (!await _root.exists()) return 0;
      var n = 0;
      await for (final f in _root.list()) {
        if (f is File && f.path.endsWith('.json')) {
          try {
            final j = jsonDecode(await f.readAsString());
            if (j is List) n += j.length;
          } catch (_) {}
        }
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      if (await _root.exists()) await _root.delete(recursive: true);
    } catch (_) {}
  }
}
