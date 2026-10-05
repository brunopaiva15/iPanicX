import '../l10n/strings.dart';
import '../models/device_facts.dart';
import '../models/scan_result.dart';
import 'correlation.dart';
import 'knowledge_base.dart';

enum CheckStatus {
  ok,
  warning,
  problem,

  /// Neutral fact (Developer Mode, Wi-Fi address).
  info,

  /// iOS does not expose it, or no scan yet.
  unavailable,
}

class HealthCheck {
  const HealthCheck({
    required this.id,
    required this.title,
    required this.status,
    required this.value,
    this.detail,
  });

  final String id;
  final String title;
  final CheckStatus status;
  final String value;
  final String? detail;
}

/// Device health as a checklist. Deliberately no global score: every line
/// says what was measured and where it comes from.
class HealthReport {
  const HealthReport({
    required this.checks,
    required this.groups,
    this.mainIssue,
  });

  final List<HealthCheck> checks;

  /// Correlated panics, most significant first.
  final List<ClueGroup> groups;

  /// Most significant correlated group, if any panic was found.
  final ClueGroup? mainIssue;

  CheckStatus get overall {
    if (checks.any((c) => c.status == CheckStatus.problem)) {
      return CheckStatus.problem;
    }
    if (checks.any((c) => c.status == CheckStatus.warning)) {
      return CheckStatus.warning;
    }
    return CheckStatus.ok;
  }

  static HealthReport build({
    required Strings s,
    required KnowledgeBase knowledgeBase,
    ScanResult? scan,
    DeviceFacts? facts,
    DateTime? now,
  }) {
    final groups = scan == null
        ? const <ClueGroup>[]
        : Correlator(knowledgeBase, lang: s.lang).correlate(scan.panics);
    final checks = <HealthCheck>[
      _battery(s, facts?.battery),
      _storage(s, facts?.storage),
      _panics(s, scan),
      _appCrashes(s, scan, now),
      _jetsam(s, scan, now),
      _temperature(s, facts?.battery, scan),
      _ruleCheck(s, scan, 'nand', s.checkNand, 'nand'),
      _baseband(s, scan, facts?.basebandVersion),
      _developerMode(s, facts?.developerMode),
      HealthCheck(
        id: 'wifi',
        title: s.checkWifi,
        status: facts?.wifiAddress == null
            ? CheckStatus.unavailable
            : CheckStatus.info,
        value: facts?.wifiAddress ?? s.unavailable,
        detail: s.checkWifiDetail,
      ),
    ];
    return HealthReport(
      checks: checks,
      groups: groups,
      mainIssue: groups.isEmpty ? null : groups.first,
    );
  }

  static HealthCheck _battery(Strings s, BatteryInfo? b) {
    final health = b?.healthPercent;
    if (b == null || health == null) {
      return HealthCheck(
        id: 'battery',
        title: s.checkBattery,
        status: CheckStatus.unavailable,
        value: b?.chargePercent == null
            ? s.unavailable
            : s.chargeOnly(b!.chargePercent!),
        detail: s.batteryUnavailableDetail,
      );
    }
    final status = health >= 80
        ? CheckStatus.ok
        : health >= 70
        ? CheckStatus.warning
        : CheckStatus.problem;
    return HealthCheck(
      id: 'battery',
      title: s.checkBattery,
      status: status,
      value: [
        s.healthValue(health),
        if (b.cycleCount != null) s.cycles(b.cycleCount!),
      ].join(' · '),
      detail: status == CheckStatus.ok ? null : s.batteryWorn,
    );
  }

  static HealthCheck _storage(Strings s, StorageInfo? st) {
    if (st == null) {
      return HealthCheck(
        id: 'storage',
        title: s.checkStorage,
        status: CheckStatus.unavailable,
        value: s.unavailable,
      );
    }
    final u = st.usedPercent;
    return HealthCheck(
      id: 'storage',
      title: s.checkStorage,
      status: u > 97
          ? CheckStatus.problem
          : u >= 90
          ? CheckStatus.warning
          : CheckStatus.ok,
      value: s.storageUsed(u),
      detail: u >= 90 ? s.storageFullDetail : null,
    );
  }

  static HealthCheck _noScan(Strings s, String id, String title) => HealthCheck(
    id: id,
    title: title,
    status: CheckStatus.unavailable,
    value: s.notScanned,
  );

  static HealthCheck _panics(Strings s, ScanResult? scan) {
    if (scan == null) return _noScan(s, 'panics', s.kernelPanicsLabel);
    final n = scan.panics.length;
    return HealthCheck(
      id: 'panics',
      title: s.kernelPanicsLabel,
      status: n == 0
          ? CheckStatus.ok
          : scan.health.verdict.name == 'hardwareIssueLikely'
          ? CheckStatus.problem
          : CheckStatus.warning,
      value: n == 0 ? s.noneFound : s.detected(n),
    );
  }

  static HealthCheck _appCrashes(Strings s, ScanResult? scan, DateTime? now) {
    if (scan == null) return _noScan(s, 'apps', s.checkAppCrashes);
    final list = scan.appCrashes(now: now);
    final byApp = <String, int>{};
    for (final r in list) {
      final name = r.name ?? r.file.name.split('-').first;
      byApp[name] = (byApp[name] ?? 0) + 1;
    }
    final top = byApp.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return HealthCheck(
      id: 'apps',
      title: s.checkAppCrashes,
      status: list.length > 5 ? CheckStatus.warning : CheckStatus.ok,
      value: s.inLastDays(list.length, 7),
      detail: top.isEmpty
          ? null
          : top.take(3).map((e) => '${e.key} (${e.value}×)').join(', '),
    );
  }

  static HealthCheck _jetsam(Strings s, ScanResult? scan, DateTime? now) {
    if (scan == null) return _noScan(s, 'jetsam', s.checkJetsam);
    final n = scan.jetsamEvents(now: now).length;
    return HealthCheck(
      id: 'jetsam',
      title: s.checkJetsam,
      status: n > 3 ? CheckStatus.warning : CheckStatus.ok,
      value: s.eventsInLastDays(n, 7),
      detail: n > 3 ? s.jetsamDetail : null,
    );
  }

  static HealthCheck _temperature(Strings s, BatteryInfo? b, ScanResult? scan) {
    final thermalPanics =
        scan?.panics
            .where(
              (p) =>
                  (p.result.matchedRuleId ?? '').startsWith('thermal') ||
                  p.report.missingSensors.isNotEmpty,
            )
            .length ??
        0;
    final t = b?.temperatureC;
    if (t == null && scan == null) {
      return HealthCheck(
        id: 'temperature',
        title: s.checkTemperature,
        status: CheckStatus.unavailable,
        value: s.unavailable,
      );
    }
    final status = thermalPanics > 0 || (t != null && t >= 45)
        ? CheckStatus.problem
        : t != null && t >= 40
        ? CheckStatus.warning
        : CheckStatus.ok;
    return HealthCheck(
      id: 'temperature',
      title: s.checkTemperature,
      status: status,
      value: [
        if (t != null) s.degrees(t),
        if (thermalPanics > 0) s.thermalPanics(thermalPanics),
        if (t == null && thermalPanics == 0) s.noIssueFound,
      ].join(' · '),
    );
  }

  static HealthCheck _ruleCheck(
    Strings s,
    ScanResult? scan,
    String id,
    String title,
    String rulePrefix,
  ) {
    if (scan == null) return _noScan(s, id, title);
    final n = scan.panics
        .where((p) => (p.result.matchedRuleId ?? '').startsWith(rulePrefix))
        .length;
    return HealthCheck(
      id: id,
      title: title,
      status: n > 0 ? CheckStatus.problem : CheckStatus.ok,
      value: n > 0 ? s.relatedPanics(n) : s.noIssueFound,
    );
  }

  static HealthCheck _baseband(Strings s, ScanResult? scan, String? version) {
    final c = _ruleCheck(s, scan, 'baseband', s.checkBaseband, 'baseband');
    if (version == null) return c;
    return HealthCheck(
      id: c.id,
      title: c.title,
      status: c.status == CheckStatus.unavailable ? CheckStatus.info : c.status,
      value: c.status == CheckStatus.unavailable
          ? version
          : '${c.value} · $version',
    );
  }

  static HealthCheck _developerMode(Strings s, bool? on) => HealthCheck(
    id: 'devmode',
    title: s.checkDeveloperMode,
    status: on == null ? CheckStatus.unavailable : CheckStatus.info,
    value: on == null
        ? s.unavailable
        : on
        ? s.enabled
        : s.disabled,
  );
}
