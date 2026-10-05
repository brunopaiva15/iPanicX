import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../widgets/common.dart';

/// Raw `.ips` content in a monospace, selectable view.
class RawPanicScreen extends StatelessWidget {
  const RawPanicScreen({super.key, required this.panic});

  final AnalyzedPanic panic;

  /// Rendering multi-megabyte text in one widget is slow; the full content
  /// stays available through "Copy All".
  static const _displayLimit = 300 * 1024;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final raw = panic.report.rawContent;
    final truncated = raw.length > _displayLimit;
    final shown = truncated ? raw.substring(0, _displayLimit) : raw;
    return Scaffold(
      body: Column(
        children: [
          AppToolbar(
            eyebrow: 'Raw panic report',
            title: panic.file.name,
            subtitle: truncated
                ? '${formatBytes(raw.length)} · showing the first ${formatBytes(_displayLimit)} — use “Copy All” for the full file'
                : formatBytes(raw.length),
            leading: const BackPill(),
            actions: [
              OutlinedButton.icon(
                onPressed: () =>
                    copyToClipboard(context, raw, 'Raw panic copied'),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy All'),
              ),
            ],
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(36, 0, 36, 32),
              decoration: BoxDecoration(
                color: colors.codeBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: SelectableText(
                      shown,
                      style: monoStyle(context, size: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
