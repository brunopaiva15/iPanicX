import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../models/diagnostic_file.dart';
import '../format.dart';
import '../kit.dart';
import 'panics_pane.dart';
import '../../l10n/lang_scope.dart';

class FilesPane extends StatelessWidget {
  const FilesPane({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tr;
    final scan = app.scan;
    if (scan == null) {
      return Pane(title: t.filesSection, children: const [NoScanGroup()]);
    }
    final byType = <DiagnosticFileType, List<DiagnosticFile>>{};
    for (final f in scan.files) {
      byType.putIfAbsent(f.type, () => []).add(f);
    }
    return Pane(
      title: t.filesSection,
      children: [
        Group(
          children: [
            Item(
              label: t.files(scan.files.length),
              hint: t.copiedAt(formatRelativeDate(scan.scannedAt)),
              trailing: scan.directory.isEmpty
                  ? null
                  : Btn(
                      HostPlatform.revealLabel,
                      onPressed: () async {
                        final ok = await app.bridge.revealInFinder(
                          scan.directory,
                        );
                        if (!ok && context.mounted) {
                          showToast(context, scan.directory);
                        }
                      },
                    ),
            ),
          ],
        ),
        for (final type in DiagnosticFileType.values)
          if (byType[type] != null) ...[
            Sec(type.label),
            Group(
              children: [
                for (final f in byType[type]!.take(200))
                  Item(
                    label: f.relativePath,
                    value:
                        '${formatBytes(f.sizeBytes)}  ·  ${formatRelativeDate(f.date)}',
                  ),
                if (byType[type]!.length > 200)
                  CapItem(t.andMore(byType[type]!.length - 200)),
              ],
            ),
          ],
      ],
    );
  }
}
