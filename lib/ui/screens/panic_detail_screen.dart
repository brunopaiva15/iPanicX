import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../diagnostics/report_formatter.dart';
import '../../models/iphone_device.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/diagnostic_card.dart';

class PanicDetailScreen extends StatelessWidget {
  const PanicDetailScreen({super.key, required this.panic});

  final AnalyzedPanic panic;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final colors = AppColors.of(context);
    final r = panic.result;
    final p = panic.report;
    final device = app.status.device;
    final sev = colors.severity(r.severity);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AppToolbar(
              eyebrow: 'Panic diagnosis',
              title: panic.file.name,
              subtitle: formatRelativeDate(panic.date),
              leading: const BackPill(),
              actions: [
                OutlinedButton.icon(
                  onPressed: () => AppRouter.openRaw(context, panic),
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: const Text('View Raw Panic'),
                ),
                FilledButton.icon(
                  onPressed: () => _export(context, device),
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Export Report'),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: PageBody(
              children: [
                DiagnosticCard(
                  result: r,
                  footer: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => copyToClipboard(
                          context,
                          ReportFormatter.diagnosis(panic, device: device),
                          'Diagnosis copied',
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text('Copy Diagnosis'),
                      ),
                      if (p.hasPanicString)
                        OutlinedButton.icon(
                          onPressed: () => copyToClipboard(
                            context,
                            p.panicString!,
                            'Panic string copied',
                          ),
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                          ),
                          label: const Text('Copy Panic String'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (r.isKnownSignature) ...[
                  _TwoColumns(
                    left: SectionCard(
                      title: 'Suspected components',
                      icon: Icons.memory_rounded,
                      child: r.suspectedComponents.isEmpty
                          ? Text(
                              'No specific component identified',
                              style: TextStyle(color: colors.secondaryText),
                            )
                          : Column(
                              children: [
                                for (final c in r.suspectedComponents)
                                  _ComponentRow(name: c, color: sev),
                              ],
                            ),
                    ),
                    right: SectionCard(
                      title: 'Possible causes',
                      icon: Icons.manage_search_rounded,
                      child: BulletList(items: r.possibleCauses),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (r.recommendedActions.isNotEmpty) ...[
                  SectionCard(
                    title: r.isKnownSignature
                        ? 'Recommended actions'
                        : 'Next steps',
                    icon: Icons.build_rounded,
                    child: BulletList(
                      items: r.recommendedActions,
                      numbered: true,
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
                Group(
                  label: 'Technical details',
                  children: [
                    InfoRow(
                      label: 'Device',
                      value: p.product ?? device?.productType,
                      monospace: true,
                    ),
                    InfoRow(
                      label: 'Model',
                      value: marketingNameFor(p.product ?? device?.productType),
                    ),
                    InfoRow(
                      label: 'iOS',
                      value: [
                        p.osVersion ?? device?.productVersion,
                        if (p.build != null) '(${p.build})',
                      ].whereType<String>().join(' '),
                    ),
                    InfoRow(
                      label: 'Sensor Mask',
                      value: p.sensorMask == null
                          ? null
                          : '${p.sensorMaskHex}  (${p.sensorMask} decimal)',
                      monospace: true,
                    ),
                    if (p.sensorKeys.isNotEmpty)
                      InfoRow(
                        label: 'SMC keys',
                        value: p.sensorKeys.join(', '),
                        monospace: true,
                      ),
                    if (p.missingSensors.isNotEmpty)
                      InfoRow(
                        label: 'Missing sensors',
                        value: p.missingSensors.join(', '),
                        monospace: true,
                      ),
                    InfoRow(label: 'Panic', value: p.headline),
                    InfoRow(label: 'Initiator', value: p.panicInitiator),
                    if (p.panickedProcess != null)
                      InfoRow(label: 'Panicked task', value: p.panickedProcess),
                    if (p.backtraceKexts.isNotEmpty)
                      InfoRow(
                        label: 'Kexts',
                        value: p.backtraceKexts.join('\n'),
                        monospace: true,
                      ),
                    if (p.panicFlags != null)
                      InfoRow(
                        label: 'Panic flags',
                        value: p.panicFlags,
                        monospace: true,
                      ),
                    if (p.kernelVersion != null)
                      InfoRow(label: 'Kernel', value: p.kernelVersion),
                    InfoRow(
                      label: 'Bug type',
                      value: p.bugType,
                      monospace: true,
                    ),
                    InfoRow(label: 'SoC', value: p.socId, monospace: true),
                    InfoRow(
                      label: 'Incident',
                      value: p.incident,
                      monospace: true,
                    ),
                    InfoRow(
                      label: 'Date',
                      value: panic.date == null
                          ? null
                          : formatDate(panic.date!),
                    ),
                    InfoRow(
                      label: 'File',
                      value: panic.file.relativePath,
                      monospace: true,
                    ),
                    if (r.matchedRuleId != null)
                      InfoRow(
                        label: 'Rule',
                        value: r.matchedRuleId,
                        monospace: true,
                      ),
                    if (r.evidence.isNotEmpty)
                      InfoRow(
                        label: 'Matched on',
                        value: r.evidence.join(' · '),
                      ),
                  ],
                ),
                if (r.rawCodes.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const Padding(
                    padding: EdgeInsets.only(left: 6, bottom: 10),
                    child: SectionLabel('Detected codes'),
                  ),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final c in r.rawCodes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(c, style: monoStyle(context, size: 11.5)),
                        ),
                    ],
                  ),
                ],
                if (p.hasPanicString) ...[
                  const SizedBox(height: 26),
                  const Padding(
                    padding: EdgeInsets.only(left: 6, bottom: 10),
                    child: SectionLabel('Panic string'),
                  ),
                  CodeBlock(text: p.panicString!.trim(), maxHeight: 240),
                ],
                if (p.parseWarnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TechnicalDetails(
                    title: 'Parser notes',
                    details: p.parseWarnings.join('\n'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, IPhoneDevice? device) async {
    final app = AppScope.read(context);
    final base = panic.file.name.replaceAll(RegExp(r'\.ips.*$'), '');
    final saved = await app.bridge.saveTextFile(
      suggestedName: 'iPaniX-$base.txt',
      contents: ReportFormatter.diagnosis(panic, device: device),
    );
    if (!context.mounted || saved == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Report saved to $saved'),
        action: SnackBarAction(
          label: HostPlatform.revealLabel,
          onPressed: () => app.bridge.revealInFinder(saved),
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 680) {
          return Column(children: [left, const SizedBox(height: 20), right]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 20),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }
}
