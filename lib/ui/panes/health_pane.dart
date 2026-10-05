import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../diagnostics/correlation.dart';
import '../../diagnostics/health_report.dart';
import '../../diagnostics/report_formatter.dart';
import '../../l10n/lang_scope.dart';
import '../../l10n/strings.dart';
import '../../models/device_facts.dart';
import '../format.dart';
import '../kit.dart';
import '../ring.dart';
import '../shell.dart';
import 'shared.dart';

/// "Device Health": checklist, main issue, battery, storage, correlation.
class HealthPane extends StatelessWidget {
  const HealthPane({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tr;
    final c = AppColors.of(context);
    final connected = app.status.isConnected;
    final report = app.health;
    final facts = app.facts;

    return Pane(
      title: t.healthSection,
      trailing: connected
          ? (app.loadingFacts
                ? UsageRing(
                    size: 16,
                    fraction: 0,
                    color: c.text2,
                    track: c.segBg,
                    spinning: true,
                  )
                : Btn(t.refresh, onPressed: app.loadFacts))
          : null,
      children: [
        if (!connected && app.scan == null)
          Group(
            children: [
              Item(
                leading: const Glyph(Icons.phone_iphone),
                label: t.healthNeedsDevice,
              ),
            ],
          )
        else ...[
          _Summary(report: report),
          if (app.previousScan != null) ...[
            const SizedBox(height: 10),
            _SinceLast(app: app),
          ],
          if (app.scan == null) ...[
            const SizedBox(height: 10),
            Group(
              children: [
                Item(
                  label: t.scanDiagnostics,
                  hint: t.healthNeedsScan,
                  trailing: app.isScanning
                      ? null
                      : Btn(
                          t.scanButton,
                          primary: true,
                          onPressed: app.scanDiagnostics,
                        ),
                ),
              ],
            ),
          ],
          if (report.mainIssue != null) ...[
            Sec(t.mainIssue),
            _ClueDetail(group: report.mainIssue!),
          ],
          Sec(t.checklist),
          Group(children: [for (final ch in report.checks) _CheckItem(ch)]),
          if (facts?.battery != null) ...[
            Sec(t.battery),
            _BatteryGroup(battery: facts!.battery!),
          ],
          if (facts?.storage != null) ...[
            Sec(t.storageSection),
            Group(
              children: [
                Item(
                  label: t.capacity,
                  value: formatCapacity(facts!.storage!.totalBytes),
                ),
                Item(
                  label: t.used,
                  value:
                      '${formatCapacity(facts.storage!.usedBytes)}  '
                      '(${facts.storage!.usedPercent} %)',
                ),
                Item(
                  label: t.available,
                  value: formatCapacity(facts.storage!.availableBytes),
                ),
              ],
            ),
          ],
          if (report.groups.isNotEmpty) ...[
            Sec(t.correlation),
            Group(
              children: [
                for (final g in report.groups) _ClueItem(group: g),
                CapItem(t.correlationHint),
              ],
            ),
          ],
          Sec(t.report),
          Group(
            children: [
              Item(
                label: t.fullReport,
                hint: t.fullReportHint,
                trailing: Btn(
                  t.exportButton,
                  onPressed: () => _exportFull(context, app),
                ),
              ),
            ],
          ),
          if (facts != null && facts.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Group(
                children: [TechnicalDetails(details: facts.notes.join('\n'))],
              ),
            ),
        ],
      ],
    );
  }
}

Future<void> _exportFull(BuildContext context, AppController app) async {
  final text = FullReport.render(
    health: app.health,
    scan: app.scan,
    facts: app.facts,
    device: app.status.device,
  );
  final d = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final saved = await app.bridge.saveTextFile(
    suggestedName:
        'iPanicX-report-${d.year}-${two(d.month)}-${two(d.day)}-${two(d.hour)}${two(d.minute)}.txt',
    contents: text,
  );
  if (saved != null && context.mounted) {
    showToast(context, context.tr.savedTo(saved));
    await app.bridge.revealInFinder(saved);
  }
}

class _SinceLast extends StatelessWidget {
  const _SinceLast({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    final prev = app.previousScan!;
    final now = app.facts?.battery?.healthPercent;
    final parts = [
      t.panicsDelta(app.newPanicsSincePrevious),
      if (prev.batteryHealth != null &&
          now != null &&
          prev.batteryHealth != now)
        t.batteryDelta(prev.batteryHealth!, now),
    ];
    return Group(
      children: [
        Item(
          leading: const Glyph(Icons.history),
          label: t.sinceLastScan(formatRelativeDate(prev.date)),
          value: parts.join(' · '),
        ),
      ],
    );
  }
}

String _statusLabel(Strings t, CheckStatus s) => switch (s) {
  CheckStatus.ok => t.statusOk,
  CheckStatus.warning => t.statusWarning,
  CheckStatus.problem => t.statusProblem,
  CheckStatus.info => '',
  CheckStatus.unavailable => t.unavailable,
};

/// Round status mark: filled dot coloured by status.
class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 10});

  final CheckStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = StatusColors.of(status, AppColors.of(context));
    final hollow =
        status == CheckStatus.info || status == CheckStatus.unavailable;
    return SizedBox(
      width: 16,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hollow ? null : color,
            border: hollow ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.report});
  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tr;
    final c = AppColors.of(context);
    final d = app.status.device;
    final overall = report.overall;
    final label = switch (overall) {
      CheckStatus.problem => t.overallProblem,
      CheckStatus.warning => t.overallWarning,
      _ => t.overallOk,
    };
    return Group(
      children: [
        if (d != null)
          Item(
            leading: const Glyph(Icons.phone_iphone),
            label: d.displayName,
            value: [
              if (d.modelName != d.displayName) d.modelName,
              if (d.productVersion != null) 'iOS ${d.productVersion}',
            ].join(' · '),
          ),
        Item(
          leading: StatusDot(overall),
          label: t.overallState,
          value: label,
          valueColor: StatusColors.of(overall, c),
        ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem(this.check);
  final HealthCheck check;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Item(
      leading: Tooltip(
        message: _statusLabel(context.tr, check.status),
        child: StatusDot(check.status),
      ),
      label: check.title,
      hint: check.detail,
      value: check.value,
      valueColor:
          check.status == CheckStatus.problem ||
              check.status == CheckStatus.warning
          ? StatusColors.of(check.status, c)
          : null,
    );
  }
}

class _BatteryGroup extends StatelessWidget {
  const _BatteryGroup({required this.battery});
  final BatteryInfo battery;

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    final c = AppColors.of(context);
    final b = battery;
    final health = b.healthPercent;
    return Group(
      children: [
        if (health != null && health < 80)
          Item(
            leading: Glyph(
              Icons.warning_amber_rounded,
              color: StatusColors.of(
                health < 70 ? CheckStatus.problem : CheckStatus.warning,
                c,
              ),
            ),
            label: health < 70 ? t.batteryWornWarning : t.batteryAgingWarning,
          ),
        Item(
          label: t.charge,
          value: b.chargePercent == null
              ? t.unavailable
              : '${b.chargePercent} %'
                    '${b.isCharging == true ? ' · ${t.charging}' : ''}',
        ),
        Item(
          label: t.cycleCount,
          value: b.cycleCount?.toString() ?? t.unavailable,
        ),
        Item(
          label: t.designCapacity,
          value: b.designCapacity == null
              ? t.unavailable
              : t.mah(b.designCapacity!),
        ),
        Item(
          label: t.currentCapacity,
          value: b.fullChargeCapacity == null
              ? t.unavailable
              : t.mah(b.fullChargeCapacity!),
        ),
        Item(
          label: t.estimatedHealth,
          value: health == null ? t.unavailable : '$health %',
          valueColor: health == null || health >= 80
              ? null
              : StatusColors.of(
                  health < 70 ? CheckStatus.problem : CheckStatus.warning,
                  c,
                ),
        ),
        Item(
          label: t.batteryTemperature,
          value: b.temperatureC == null
              ? t.unavailable
              : t.degrees(b.temperatureC!),
        ),
        CapItem(t.batteryHealthHint),
      ],
    );
  }
}

String _clueTitle(Strings t, ClueGroup g) => switch (g.kind) {
  ClueKind.signature => g.value,
  _ => _capitalize('${t.clueKind(g.kind.name)} ${g.value}'),
};

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _ClueDetail extends StatelessWidget {
  const _ClueDetail({required this.group});
  final ClueGroup group;

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    final c = AppColors.of(context);
    final g = group;
    return Group(
      children: [
        Item(
          leading: Glyph(
            Icons.warning_amber_rounded,
            color: g.isHardware ? c.danger : StatusColors.warning,
          ),
          label: g.kind == ClueKind.signature
              ? g.value
              : t.sameClue(g.count, '${t.clueKind(g.kind.name)} ${g.value}'),
          wrapValue: true,
        ),
        Item(
          label: t.probableCause,
          value: g.component ?? t.componentUnknown,
          wrapValue: (g.component ?? '').length > 40,
        ),
        Item(label: t.occurrences, value: '${g.count}'),
        Item(label: t.firstSeen, value: formatRelativeDate(g.first)),
        Item(label: t.lastSeen, value: formatRelativeDate(g.last)),
        Item(label: t.confidence, value: g.confidence.label),
        if (g.note != null) CapItem(g.note!),
        if (g.isHardware) CapItem(t.knownSignatureDisclaimer),
        Item(
          label: t.latestReport,
          hint: g.panics.first.file.name,
          trailing: Btn(
            t.analyze,
            onPressed: () => ShellScope.of(context).openPanic(g.panics.first),
          ),
        ),
      ],
    );
  }
}

class _ClueItem extends StatelessWidget {
  const _ClueItem({required this.group});
  final ClueGroup group;

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    final c = AppColors.of(context);
    final g = group;
    return Item(
      leading: UsageRing(
        size: 18,
        fraction: confidenceFraction(g.confidence),
        color: g.isHardware ? Notch.critical : c.text2,
        track: c.segBg,
      ),
      label: _clueTitle(t, g),
      hint: g.component,
      value: '${g.count}×  ·  ${formatShortDate(g.last)}',
      trailing: Icon(Icons.chevron_right, size: 16, color: c.text3),
      onTap: () => ShellScope.of(context).openPanic(g.panics.first),
    );
  }
}
