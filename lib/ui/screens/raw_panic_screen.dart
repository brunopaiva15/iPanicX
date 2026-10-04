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
      body: SafeArea(
        child: Column(
          children: [
            AppToolbar(
              title: panic.file.name,
              subtitle: '${formatBytes(raw.length)} · raw panic report',
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: () =>
                      copyToClipboard(context, raw, 'Raw panic copied'),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy All'),
                ),
              ],
            ),
            if (truncated)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Showing the first ${formatBytes(_displayLimit)}. Use “Copy All” for the full file.',
                  style: TextStyle(color: colors.orange, fontSize: 12),
                ),
              ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  color: colors.codeBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
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
      ),
    );
  }
}
