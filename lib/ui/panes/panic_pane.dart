import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../diagnostics/report_formatter.dart';
import '../../models/iphone_device.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../kit.dart';
import '../notch.dart';
import '../shell.dart';
import 'shared.dart';

class PanicPane extends StatelessWidget {
  const PanicPane({super.key, required this.panic});

  final AnalyzedPanic panic;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final r = panic.result;
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
              label: 'Severity',
              value: r.severity.label,
              valueColor: r.severity.name == 'unknown' ? null : severity,
            ),
            Item(label: 'Confidence', value: r.confidence.label),
            if (r.disclaimer != null) CapItem(r.disclaimer!),
          ],
        ),
        if (r.isKnownSignature && r.suspectedComponents.isNotEmpty) ...[
          const Sec('Suspected components'),
          Group(
            children: [
              for (final s in r.suspectedComponents)
                Item(leading: Glyph(glyphFor(r)), label: s),
            ],
          ),
        ],
        if (r.possibleCauses.isNotEmpty) ...[
          const Sec('Possible causes'),
          Group(children: [for (final s in r.possibleCauses) Item(label: s)]),
        ],
        if (r.recommendedActions.isNotEmpty) ...[
          Sec(r.isKnownSignature ? 'Recommended actions' : 'Next steps'),
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
        const Sec('Technical details'),
        Group(
          children: [
            Item(
              label: 'Device',
              value: p.product ?? device?.productType,
              mono: true,
            ),
            Item(
              label: 'Model',
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
                label: 'Sensor mask',
                value: '${p.sensorMaskHex}  (${p.sensorMask})',
                mono: true,
              ),
            if (p.sensorKeys.isNotEmpty)
              Item(
                label: 'SMC keys',
                value: p.sensorKeys.join(', '),
                mono: true,
              ),
            if (p.missingSensors.isNotEmpty)
              Item(
                label: 'Missing sensors',
                value: p.missingSensors.join(', '),
                mono: true,
              ),
            if (p.headline != null)
              Item(label: 'Panic', value: p.headline, wrapValue: true),
            if (p.panicInitiator != null)
              Item(label: 'Initiator', value: p.panicInitiator),
            if (p.panickedProcess != null)
              Item(label: 'Panicked task', value: p.panickedProcess),
            if (p.backtraceKexts.isNotEmpty)
              Item(
                label: 'Kexts in backtrace',
                value: p.backtraceKexts.join('\n'),
                mono: true,
                wrapValue: true,
              ),
            if (p.panicFlags != null)
              Item(label: 'Panic flags', value: p.panicFlags, mono: true),
            if (p.bugType != null)
              Item(label: 'Bug type', value: p.bugType, mono: true),
            if (p.socId != null) Item(label: 'SoC', value: p.socId, mono: true),
            if (p.kernelVersion != null)
              Item(label: 'Kernel', value: p.kernelVersion, wrapValue: true),
            if (p.incident != null)
              Item(label: 'Incident', value: p.incident, mono: true),
            Item(
              label: 'Date',
              value: panic.date == null ? '—' : formatDate(panic.date!),
            ),
            if (r.matchedRuleId != null)
              Item(label: 'Rule', value: r.matchedRuleId, mono: true),
            if (r.evidence.isNotEmpty)
              Item(
                label: 'Matched on',
                value: r.evidence.join(' · '),
                wrapValue: true,
              ),
            if (r.rawCodes.isNotEmpty)
              Item(
                label: 'Detected codes',
                value: r.rawCodes.join('  ·  '),
                mono: true,
                wrapValue: true,
              ),
            if (p.parseWarnings.isNotEmpty)
              TechnicalDetails(
                label: 'Parser notes',
                details: p.parseWarnings.join('\n'),
              ),
          ],
        ),
        if (p.hasPanicString) ...[
          const Sec('Panic string'),
          Group(children: [CapItem(p.panicString!.trim(), mono: true)]),
        ],
        const Sec('Report'),
        Group(
          children: [
            Item(
              label: 'Raw report',
              hint: panic.file.relativePath,
              trailing: Btn(
                'View Raw Panic',
                onPressed: ShellScope.of(context).openRaw,
              ),
            ),
            Item(
              label: 'Diagnosis',
              hint: 'Plain text, as exported',
              trailing: Btn(
                'Copy',
                onPressed: () => copyText(
                  context,
                  ReportFormatter.diagnosis(panic, device: device),
                  'Diagnosis copied',
                ),
              ),
            ),
            if (p.hasPanicString)
              Item(
                label: 'Panic string',
                trailing: Btn(
                  'Copy',
                  onPressed: () =>
                      copyText(context, p.panicString!, 'Panic string copied'),
                ),
              ),
            Item(
              label: 'Export',
              hint: 'Save the diagnosis as a .txt file',
              trailing: Btn(
                'Export Report…',
                onPressed: () => _export(context, device),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, IPhoneDevice? device) async {
    final app = AppScope.read(context);
    final base = panic.file.name.replaceAll(RegExp(r'\.ips.*$'), '');
    final saved = await app.bridge.saveTextFile(
      suggestedName: 'iPaniX-$base.txt',
      contents: ReportFormatter.diagnosis(panic, device: device),
    );
    if (saved != null && context.mounted) {
      showToast(context, 'Saved to $saved');
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
    final cut = raw.length > _limit;
    return Pane(
      title: panic.file.name,
      leading: const BackButtonSmall(),
      trailing: Btn(
        'Copy All',
        onPressed: () => copyText(context, raw, 'Raw panic copied'),
      ),
      children: [
        Group(
          children: [
            if (cut)
              CapItem(
                'Showing the first ${formatBytes(_limit)} of '
                '${formatBytes(raw.length)}. Copy All copies everything.',
              ),
            CapItem(cut ? raw.substring(0, _limit) : raw, mono: true),
          ],
        ),
      ],
    );
  }
}
