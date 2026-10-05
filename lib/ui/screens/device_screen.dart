import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../models/diagnostic_file.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/panic_card.dart';

/// Every diagnostic file copied during the last scan, grouped by type.
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scan = app.scan;
    final device = app.status.device;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AppToolbar(
              eyebrow: 'Diagnostic files',
              title: device?.displayName ?? 'Diagnostic Files',
              subtitle: scan == null
                  ? null
                  : '${plural(scan.files.length, 'file')} · scanned ${formatRelativeDate(scan.scannedAt)}',
              leading: const BackPill(),
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
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: Text(HostPlatform.revealLabel),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: scan == null
                ? const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: Text('Run a scan first.')),
                  )
                : _FileList(scan: scan),
          ),
        ],
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
        if (scan.panics.isEmpty)
          Group(
            label: 'Kernel panics',
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'No panic reports found',
                  style: TextStyle(color: colors.secondaryText),
                ),
              ),
            ],
          )
        else
          Group(
            label: 'Kernel panics · ${scan.panics.length}',
            children: [
              for (final p in scan.panics)
                PanicCard(
                  panic: p,
                  onTap: () => AppRouter.openPanic(context, p),
                ),
            ],
          ),
        if (scan.forcedResets.isNotEmpty) ...[
          const SizedBox(height: 26),
          Group(
            label: 'Forced restarts · ${scan.forcedResets.length}',
            children: [
              for (final p in scan.forcedResets)
                PanicCard(
                  panic: p,
                  onTap: () => AppRouter.openPanic(context, p),
                ),
            ],
          ),
        ],
        for (final type in DiagnosticFileType.values)
          if (others[type] != null) ...[
            const SizedBox(height: 26),
            Group(
              label: '${type.label} · ${others[type]!.length}',
              children: [
                for (final f in others[type]!.take(200))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_rounded,
                          size: 16,
                          color: colors.secondaryText,
                        ),
                        const SizedBox(width: 12),
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
                        const SizedBox(width: 18),
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
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '…and ${others[type]!.length - 200} more',
                      style: TextStyle(color: colors.tertiaryText),
                    ),
                  ),
              ],
            ),
          ],
        const SizedBox(height: 18),
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
