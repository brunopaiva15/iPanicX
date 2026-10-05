import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../diagnostics/report_formatter.dart';
import '../../l10n/lang_scope.dart';
import '../../models/diagnostic_result.dart';
import '../../models/iphone_device.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../kit.dart';
import '../ring.dart';
import '../shell.dart';
import 'shared.dart';

class PanicPane extends StatelessWidget {
  const PanicPane({super.key, required this.panic});

  final AnalyzedPanic panic;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final t = context.tr;
    // Re-generated in the current language (the panic may come from a scan
    // or a local file analysed before a language change).
    final r = app.diagnostics.analyzer.analyze(panic.report);
    final p = panic.report;
    final device = app.status.device;
    final severity = Notch.severity(r.severity);

    return Pane(
      title: r.title,
      leading: const BackButtonSmall(),
      children: [
        Group(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UsageRing(
                    size: 18,
                    fraction: r.isKnownSignature
                        ? confidenceFraction(r.confidence)
                        : 0,
                    color: severity,
                    track: c.segBg,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.summary,
                      style: TextStyle(
                        fontSize: kBodySize,
                        color: c.text,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Item(
              label: t.severity,
              value: r.severity.label,
              valueColor: r.severity.name == 'unknown' ? null : severity,
            ),
            Item(label: t.confidence, value: r.confidence.label),
            if (r.disclaimer != null) CapItem(r.disclaimer!),
          ],
        ),
        if (r.isKnownSignature && r.suspectedComponents.isNotEmpty) ...[
          Sec(t.suspectedComponents),
          Group(
            children: [
              for (final s in r.suspectedComponents)
                Item(leading: Glyph(glyphFor(r)), label: s),
            ],
          ),
        ],
        if (r.possibleCauses.isNotEmpty) ...[
          Sec(t.possibleCauses),
          Group(children: [for (final s in r.possibleCauses) Item(label: s)]),
        ],
        if (r.recommendedActions.isNotEmpty) ...[
          Sec(r.isKnownSignature ? t.recommendedActions : t.nextSteps),
          Group(
            children: [
              for (var i = 0; i < r.recommendedActions.length; i++)
                Item(
                  leading: SizedBox(
                    width: 16,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  ),
                  label: r.recommendedActions[i],
                ),
            ],
          ),
        ],
        Sec(t.technicalDetails),
        Group(
          children: [
            Item(
              label: t.device,
              value: p.product ?? device?.productType,
              mono: true,
            ),
            Item(
              label: t.model,
              value: marketingNameFor(p.product ?? device?.productType),
            ),
            Item(
              label: 'iOS',
              value: [
                p.osVersion ?? device?.productVersion,
                if (p.build != null) '(${p.build})',
              ].whereType<String>().join(' '),
            ),
            if (p.sensorMask != null)
              Item(
                label: t.sensorMask,
                value: '${p.sensorMaskHex}  (${p.sensorMask})',
                mono: true,
              ),
            if (p.sensorKeys.isNotEmpty)
              Item(
                label: t.smcKeys,
                value: p.sensorKeys.join(', '),
                mono: true,
              ),
            if (p.missingSensors.isNotEmpty)
              Item(
                label: t.missingSensors,
                value: p.missingSensors.join(', '),
                mono: true,
              ),
            if (p.headline != null)
              Item(label: t.panic, value: p.headline, wrapValue: true),
            if (p.panicInitiator != null)
              Item(label: t.initiator, value: p.panicInitiator),
            if (p.panickedProcess != null)
              Item(label: t.panickedTask, value: p.panickedProcess),
            if (p.backtraceKexts.isNotEmpty)
              Item(
                label: t.kexts,
                value: p.backtraceKexts.join('\n'),
                mono: true,
                wrapValue: true,
              ),
            if (p.panicFlags != null)
              Item(label: t.panicFlags, value: p.panicFlags, mono: true),
            if (p.bugType != null)
              Item(label: t.bugType, value: p.bugType, mono: true),
            if (p.socId != null) Item(label: 'SoC', value: p.socId, mono: true),
            if (p.kernelVersion != null)
              Item(label: t.kernel, value: p.kernelVersion, wrapValue: true),
            if (p.incident != null)
              Item(label: 'Incident', value: p.incident, mono: true),
            Item(
              label: t.date,
              value: panic.date == null ? '—' : formatDate(panic.date!),
            ),
            if (r.matchedRuleId != null)
              Item(label: t.rule, value: r.matchedRuleId, mono: true),
            if (r.evidence.isNotEmpty)
              Item(
                label: t.matchedOn,
                value: r.evidence.join(' · '),
                wrapValue: true,
              ),
            if (r.rawCodes.isNotEmpty)
              Item(
                label: t.detectedCodes,
                value: r.rawCodes.join('  ·  '),
                mono: true,
                wrapValue: true,
              ),
            if (p.parseWarnings.isNotEmpty)
              TechnicalDetails(
                label: t.parserNotes,
                details: p.parseWarnings.join('\n'),
              ),
          ],
        ),
        if (p.hasPanicString) ...[
          Sec(t.panicString),
          Group(children: [CapItem(p.panicString!.trim(), mono: true)]),
        ],
        Sec(t.report),
        Group(
          children: [
            Item(
              label: t.rawReport,
              hint: panic.file.relativePath,
              trailing: Btn(
                t.viewRaw,
                onPressed: ShellScope.of(context).openRaw,
              ),
            ),
            Item(
              label: t.diagnosis,
              hint: t.diagnosisHint,
              trailing: Btn(
                t.copy,
                onPressed: () => copyText(
                  context,
                  ReportFormatter.diagnosis(_current(r), device: device),
                  t.diagnosisCopied,
                ),
              ),
            ),
            if (p.hasPanicString)
              Item(
                label: t.panicString,
                trailing: Btn(
                  t.copy,
                  onPressed: () =>
                      copyText(context, p.panicString!, t.panicStringCopied),
                ),
              ),
            Item(
              label: t.export,
              hint: t.exportHint,
              trailing: Btn(
                t.exportButton,
                onPressed: () => _export(context, _current(r), device),
              ),
            ),
          ],
        ),
      ],
    );
  }

  AnalyzedPanic _current(DiagnosticResult r) =>
      AnalyzedPanic(file: panic.file, report: panic.report, result: r);

  Future<void> _export(
    BuildContext context,
    AnalyzedPanic current,
    IPhoneDevice? device,
  ) async {
    final app = AppScope.read(context);
    final base = panic.file.name.replaceAll(RegExp(r'\.ips.*$'), '');
    final saved = await app.bridge.saveTextFile(
      suggestedName: 'iPanicX-$base.txt',
      contents: ReportFormatter.diagnosis(current, device: device),
    );
    if (saved != null && context.mounted) {
      showToast(context, context.tr.savedTo(saved));
      await app.bridge.revealInFinder(saved);
    }
  }
}

class RawPane extends StatelessWidget {
  const RawPane({super.key, required this.panic});

  final AnalyzedPanic panic;

  /// Rendering megabytes in one text widget is slow; Copy All has it all.
  static const _limit = 300 * 1024;

  @override
  Widget build(BuildContext context) {
    final raw = panic.report.rawContent;
    final t = context.tr;
    final cut = raw.length > _limit;
    return Pane(
      title: panic.file.name,
      leading: const BackButtonSmall(),
      trailing: Btn(
        t.copyAll,
        onPressed: () => copyText(context, raw, t.rawCopied),
      ),
      children: [
        Group(
          children: [
            if (cut)
              CapItem(
                t.showingFirst(formatBytes(_limit), formatBytes(raw.length)),
              ),
            CapItem(cut ? raw.substring(0, _limit) : raw, mono: true),
          ],
        ),
      ],
    );
  }
}
