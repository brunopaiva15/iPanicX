import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/diagnostic_result.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../kit.dart';
import '../notch.dart';
import '../shell.dart';

double confidenceFraction(Confidence c) => switch (c) {
  Confidence.high => 1,
  Confidence.medium => 0.66,
  Confidence.low => 0.33,
  Confidence.none => 0,
};

/// Monochrome glyph per signature family, like Codenotch's provider glyphs.
IconData glyphFor(DiagnosticResult r) {
  final id = r.matchedRuleId ?? '';
  if (id.startsWith('smc') || id.startsWith('aop')) return Icons.sensors;
  if (id.startsWith('thermal')) return Icons.thermostat;
  if (id.startsWith('nand')) return Icons.storage;
  if (id.startsWith('gpu')) return Icons.blur_on;
  if (id.startsWith('baseband')) return Icons.cell_tower;
  if (id.startsWith('sep')) return Icons.fingerprint;
  if (id.startsWith('dart')) return Icons.device_hub;
  if (id.startsWith('forced')) return Icons.restart_alt;
  if (id.contains('watchdog')) return Icons.timer_outlined;
  if (id.contains('memory')) return Icons.memory;
  return r.isKnownSignature ? Icons.memory : Icons.help_outline;
}

/// Panics sharing a signature, newest first.
class SignatureGroup {
  SignatureGroup(this.title, this.panics);
  final String title;
  final List<AnalyzedPanic> panics;
  AnalyzedPanic get latest => panics.first;
}

List<SignatureGroup> groupBySignature(List<AnalyzedPanic> panics) {
  final map = <String, List<AnalyzedPanic>>{};
  for (final p in panics) {
    final key = p.result.isKnownSignature
        ? p.result.title
        : (p.report.signature ?? p.result.title);
    map.putIfAbsent(key, () => []).add(p);
  }
  final groups = [for (final e in map.entries) SignatureGroup(e.key, e.value)]
    ..sort((a, b) => b.panics.length.compareTo(a.panics.length));
  return groups;
}

/// Notch cells for the most frequent signatures (at most [max]).
List<NotchCell> notchCells(
  BuildContext context,
  List<AnalyzedPanic> panics, {
  int max = 3,
}) {
  final shell = ShellScope.of(context);
  final total = panics.length;
  return [
    for (final g in groupBySignature(panics).take(max))
      () {
        final r = g.latest.result;
        final share = g.panics.length / total;
        final severity = Notch.severity(r.severity);
        return NotchCell(
          icon: glyphFor(r),
          fraction: share,
          color: severity,
          reading: '${(share * 100).round()}%',
          onOpen: () => shell.openPanic(g.latest),
          card: TooltipCardData(
            icon: glyphFor(r),
            title: r.isKnownSignature ? r.title : 'Unknown signature',
            blocks: [
              TooltipBlock(
                label: 'Kernel panics',
                note: 'Latest ${formatShortDate(g.latest.date)}',
                fraction: share,
                color: Notch.band(share),
                reading: '${g.panics.length} of $total',
              ),
              TooltipBlock(
                label: 'Confidence',
                note: r.severity == Severity.unknown
                    ? 'Severity unknown'
                    : '${r.severity.label} severity',
                fraction: r.isKnownSignature
                    ? confidenceFraction(r.confidence)
                    : 0,
                color: severity,
                reading: r.isKnownSignature
                    ? r.confidence.label
                    : 'Not in the knowledge base',
              ),
            ],
          ),
        );
      }(),
  ];
}

/// A row for one panic: small ring (confidence, severity colour), title,
/// date, chevron.
class PanicItem extends StatelessWidget {
  const PanicItem({super.key, required this.panic});

  final AnalyzedPanic panic;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final r = panic.result;
    return Item(
      leading: UsageRing(
        size: 18,
        fraction: r.isKnownSignature ? confidenceFraction(r.confidence) : 0,
        color: Notch.severity(r.severity),
        track: c.segBg,
      ),
      label: r.title,
      hint: panic.report.headline ?? panic.file.name,
      value: formatRelativeDate(panic.date),
      trailing: Icon(Icons.chevron_right, size: 16, color: c.text3),
      onTap: () => ShellScope.of(context).openPanic(panic),
    );
  }
}

/// Back control in a pane head.
class BackButtonSmall extends StatelessWidget {
  const BackButtonSmall({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: 'Back',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: ShellScope.of(context).back,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c.btn,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.chevron_left, size: 18, color: c.text),
          ),
        ),
      ),
    );
  }
}
