import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../diagnostics/app_crash.dart';
import '../../l10n/lang_scope.dart';
import '../../models/diagnostic_file.dart';
import '../format.dart';
import '../kit.dart';
import '../shell.dart';
import 'panics_pane.dart';
import 'shared.dart';

/// App crashes of a period: pattern, per-day bars, by app, by cause.
class AppCrashesPane extends StatelessWidget {
  const AppCrashesPane({super.key, required this.days});

  /// 7, 30 or null (all).
  final int? days;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final shell = ShellScope.of(context);
    final t = context.tr;
    final c = AppColors.of(context);
    final scan = app.scan;
    if (scan == null) {
      return Pane(
        title: t.appCrashesTitle,
        leading: const BackButtonSmall(),
        children: const [NoScanGroup()],
      );
    }
    final sum = scan.crashSummary(days: days);
    final pattern = sum.pattern;
    final top = sum.apps.isEmpty ? null : sum.apps.first;

    return Pane(
      title: t.appCrashesTitle,
      leading: const BackButtonSmall(),
      trailing: Seg<int?>(
        options: {7: t.period7, 30: t.period30, null: t.periodAll},
        value: days,
        onChanged: shell.setCrashDays,
      ),
      children: [
        Group(
          children: [
            Item(
              leading: const Glyph(Icons.apps),
              label: t.crashCount(sum.total),
              value: t.appCount(sum.apps.length),
            ),
            if (pattern != null)
              Item(
                leading: Glyph(
                  pattern == CrashPattern.systemWide ||
                          pattern == CrashPattern.thermal
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline,
                  color:
                      pattern == CrashPattern.systemWide ||
                          pattern == CrashPattern.thermal
                      ? c.danger
                      : c.text2,
                ),
                label: t.crashPatternTitle(pattern.name),
                hint: t.crashPatternExplain(
                  pattern.name,
                  top?.app ?? '',
                  top == null ? 0 : (top.count * 100 / sum.total).round(),
                ),
              ),
            if (sum.total == 0) CapItem(t.noCrashes),
          ],
        ),
        if (days != null && sum.total > 0) ...[
          Sec(t.perDay),
          Group(
            children: [
              _DayBars(
                counts: sum.perDay(scan.scannedAt, days!),
                lastDay: scan.scannedAt,
              ),
            ],
          ),
        ],
        if (sum.apps.isNotEmpty) ...[
          Sec(t.byApp),
          Group(
            children: [
              for (final g in sum.apps)
                Item(
                  leading: Glyph(g.firstParty ? Icons.apple : Icons.apps),
                  label: g.app,
                  hint: [
                    t.crashCauseLabel(g.mainCause.name),
                    if (g.firstParty) t.appleApp,
                  ].join(' · '),
                  value: '${g.count}×  ·  ${formatShortDate(g.last)}',
                  trailing: Icon(Icons.chevron_right, size: 16, color: c.text3),
                  onTap: () => shell.openCrashApp(g.app),
                ),
              CapItem(t.crashesHint),
            ],
          ),
          Sec(t.byCause),
          Group(
            children: [
              for (final e
                  in (sum.causes.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value))))
                Item(
                  label: t.crashCauseLabel(e.key.name),
                  hint: t.crashCauseExplain(e.key.name),
                  value: '${e.value}',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Crashes of one app, each expandable.
class AppCrashListPane extends StatelessWidget {
  const AppCrashListPane({super.key, required this.app, required this.days});

  final String app;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final t = context.tr;
    final scan = controller.scan;
    final crashes =
        scan
            ?.crashSummary(days: days)
            .apps
            .where((g) => g.app == app)
            .expand((g) => g.crashes)
            .toList() ??
        const <AppCrash>[];
    final first = crashes.isEmpty ? null : crashes.first;
    return Pane(
      title: app,
      leading: const BackButtonSmall(),
      children: [
        Group(
          children: [
            Item(
              leading: Glyph(
                first?.firstParty == true ? Icons.apple : Icons.apps,
              ),
              label: t.crashCount(crashes.length),
              value: first?.version == null
                  ? null
                  : '${t.appVersion} ${first!.version}',
            ),
            if (first?.bundleId != null)
              Item(label: t.bundleId, value: first!.bundleId, mono: true),
          ],
        ),
        Sec(t.crashList),
        Group(children: [for (final cr in crashes) _CrashItem(cr)]),
      ],
    );
  }
}

class _CrashItem extends StatefulWidget {
  const _CrashItem(this.crash);
  final AppCrash crash;

  @override
  State<_CrashItem> createState() => _CrashItemState();
}

class _CrashItemState extends State<_CrashItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    final c = AppColors.of(context);
    final cr = widget.crash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Item(
          label: formatRelativeDate(cr.date),
          hint: t.crashCauseLabel(cr.cause.name),
          value: cr.technical.isEmpty ? null : cr.technical,
          mono: true,
          trailing: Icon(
            _open ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: c.text2,
          ),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open) ...[
          CapItem(t.crashCauseExplain(cr.cause.name)),
          if (cr.exceptionType != null)
            Item(
              label: t.exceptionLabel,
              value: [
                cr.exceptionType,
                if (cr.signal != null) '(${cr.signal})',
                if (cr.subtype != null) '— ${cr.subtype}',
              ].whereType<String>().join(' '),
              mono: true,
              wrapValue: true,
            ),
          if (cr.terminationCode != null || cr.terminationNamespace != null)
            Item(
              label: t.terminationLabel,
              value: [
                cr.terminationNamespace,
                cr.terminationCode,
              ].whereType<String>().join(' '),
              mono: true,
            ),
          if (cr.terminationReason != null)
            Item(
              label: t.reasonLabel,
              value: cr.terminationReason,
              wrapValue: true,
            ),
          if (cr.crashedIn != null)
            Item(
              label: t.crashedInLabel,
              value: cr.crashedIn,
              mono: true,
              wrapValue: true,
            ),
          Item(
            label: t.fileLabel,
            hint: cr.file.relativePath,
            trailing: Btn(
              t.viewRawReport,
              onPressed: () => ShellScope.of(context).openRawFile(cr.file),
            ),
          ),
        ],
      ],
    );
  }
}

/// Per-day crash counts as small bars, oldest left.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.counts, required this.lastDay});
  final List<int> counts;

  /// Date of the last (rightmost) bar.
  final DateTime lastDay;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final max = counts.fold<int>(0, (a, b) => b > a ? b : a);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: SizedBox(
        height: 84,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < counts.length; i++)
              Expanded(
                child: Tooltip(
                  message: '${counts[i]}',
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: counts.length > 10 ? 1 : 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (counts.length <= 10)
                          Text(
                            '${counts[i]}',
                            style: TextStyle(fontSize: 10, color: c.text3),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: max == 0 ? 2 : 2 + 40 * counts[i] / max,
                          decoration: BoxDecoration(
                            color: counts[i] == 0 ? c.segBg : c.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          counts.length <= 10 ||
                                  (counts.length - 1 - i) % 7 == 0
                              ? '${lastDay.subtract(Duration(days: counts.length - 1 - i)).day}'
                              : '',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyle(fontSize: 10, color: c.text3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Any copied report as raw text (first 300 KB; Copy All copies all).
class RawFilePane extends StatefulWidget {
  const RawFilePane({super.key, required this.file});
  final DiagnosticFile file;

  @override
  State<RawFilePane> createState() => _RawFilePaneState();
}

class _RawFilePaneState extends State<RawFilePane> {
  static const _limit = 300 * 1024;
  late final Future<String> _content = File(
    widget.file.path,
  ).readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

  @override
  Widget build(BuildContext context) {
    final t = context.tr;
    return FutureBuilder<String>(
      future: _content,
      builder: (context, snap) {
        final raw = snap.data ?? '';
        final cut = raw.length > _limit;
        return Pane(
          title: widget.file.name,
          leading: const BackButtonSmall(),
          trailing: snap.hasData
              ? Btn(
                  t.copyAll,
                  onPressed: () => copyText(context, raw, t.rawCopied),
                )
              : null,
          children: [
            Group(
              children: [
                if (snap.hasError) CapItem(t.fileUnreadable),
                if (cut)
                  CapItem(
                    t.showingFirst(
                      formatBytes(_limit),
                      formatBytes(raw.length),
                    ),
                  ),
                if (snap.hasData)
                  CapItem(cut ? raw.substring(0, _limit) : raw, mono: true),
              ],
            ),
          ],
        );
      },
    );
  }
}
