import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../models/diagnostic_file.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/panic_card.dart';
import '../../app/host_platform.dart';

/// Every diagnostic file copied during the last scan, grouped by type.
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scan = app.scan;
    final device = app.status.device;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppToolbar(
              title: 'Diagnostic Files',
              subtitle: [
                device?.displayName,
                if (scan != null)
                  'scanned ${formatRelativeDate(scan.scannedAt)}',
              ].whereType<String>().join(' · '),
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              ),
              actions: [
                if (scan != null && scan.directory.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await app.bridge.revealInFinder(
                        scan.directory,
                      );
                      if (!ok && context.mounted) {
                        showMessage(context, scan.directory);
                      }
                    },
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: Text(HostPlatform.revealLabel),
                  ),
              ],
            ),
            Expanded(
              child: scan == null
                  ? const Center(child: Text('Run a scan first.'))
                  : _FileList(scan: scan),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final others = <DiagnosticFileType, List<DiagnosticFile>>{};
    for (final f in scan.files.where((f) => !f.isKernelReport)) {
      others.putIfAbsent(f.type, () => []).add(f);
    }
    return PageBody(
      children: [
        SectionCard(
          title: 'Kernel panics · ${scan.panics.length}',
          icon: Icons.bolt,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: scan.panics.isEmpty
              ? Text(
                  'No panic reports found',
                  style: TextStyle(color: colors.secondaryText),
                )
              : Column(
                  children: [
                    for (var i = 0; i < scan.panics.length; i++) ...[
                      if (i > 0) const Divider(indent: 12, endIndent: 12),
                      PanicCard(
                        panic: scan.panics[i],
                        onTap: () =>
                            AppRouter.openPanic(context, scan.panics[i]),
                      ),
                    ],
                  ],
                ),
        ),
        if (scan.forcedResets.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionCard(
            title: 'Forced restarts · ${scan.forcedResets.length}',
            icon: Icons.restart_alt,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
            child: Column(
              children: [
                for (var i = 0; i < scan.forcedResets.length; i++) ...[
                  if (i > 0) const Divider(indent: 12, endIndent: 12),
                  PanicCard(
                    panic: scan.forcedResets[i],
                    onTap: () =>
                        AppRouter.openPanic(context, scan.forcedResets[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        for (final type in DiagnosticFileType.values)
          if (others[type] != null) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: '${type.label} · ${others[type]!.length}',
              icon: Icons.description_outlined,
              child: Column(
                children: [
                  for (final f in others[type]!.take(200))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              f.relativePath,
                              overflow: TextOverflow.ellipsis,
                              style: monoStyle(context, size: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatBytes(f.sizeBytes),
                            style: TextStyle(
                              color: colors.tertiaryText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 150,
                            child: Text(
                              formatRelativeDate(f.date),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: colors.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (others[type]!.length > 200)
                    Text(
                      '…and ${others[type]!.length - 200} more',
                      style: TextStyle(color: colors.tertiaryText),
                    ),
                ],
              ),
            ),
          ],
        const SizedBox(height: 16),
        Text(
          'Kernel panics (panic-full / panic-base) and forced restarts are '
          'analysed. Other files are listed for reference and kept in the '
          'local folder.',
          style: TextStyle(color: colors.tertiaryText, fontSize: 12),
        ),
      ],
    );
  }
}
