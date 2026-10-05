import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../app/update_controller.dart';
import '../../l10n/lang_scope.dart';
import '../format.dart';
import '../kit.dart';
import '../ring.dart';

/// General › Updates: state, install button, automatic check setting.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.updates;
    if (!u.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        final t = context.tr;
        final c = AppColors.of(context);
        final release = u.release;
        final blocker = u.installBlocker;
        final children = <Widget>[];

        if (u.hasUpdate && release != null) {
          final pct = u.progress == null ? null : (u.progress! * 100).round();
          children.addAll([
            Item(
              leading: const Glyph(Icons.system_update_alt),
              label: t.updateAvailable(release.version),
              hint: switch (u.phase) {
                UpdatePhase.downloading => t.downloadingUpdate(pct),
                UpdatePhase.installing => t.installingUpdate,
                UpdatePhase.failed => t.updateError(u.error?.kind.name ?? ''),
                _ =>
                  blocker != null
                      ? t.installBlocked(blocker.name)
                      : app.isScanning
                      ? t.updateWaitScan
                      : t.updateInstallHint,
              },
              trailing:
                  u.phase == UpdatePhase.downloading ||
                      u.phase == UpdatePhase.installing
                  ? UsageRing(
                      size: 16,
                      fraction: u.progress ?? 0,
                      color: c.accent,
                      track: c.segBg,
                      spinning:
                          u.progress == null ||
                          u.phase == UpdatePhase.installing,
                    )
                  : Btn(
                      blocker == null ? t.installAndRestart : t.downloadUpdate,
                      primary: true,
                      onPressed: app.isScanning && blocker == null
                          ? null
                          : u.install,
                    ),
            ),
            if (release.notes.trim().isNotEmpty)
              _WhatsNew(notes: releaseNotesText(release.notes)),
            Item(
              label: 'GitHub',
              hint: release.tag,
              trailing: Btn(t.releasePage, onPressed: u.openReleasePage),
            ),
          ]);
        } else {
          children.add(
            Item(
              leading: const Glyph(Icons.update),
              label: switch (u.phase) {
                UpdatePhase.checking => t.updateChecking,
                UpdatePhase.upToDate => t.upToDate,
                UpdatePhase.failed => t.updateError(u.error?.kind.name ?? ''),
                _ => t.version,
              },
              hint: u.lastCheck == null
                  ? null
                  : t.lastChecked(formatRelativeDate(u.lastCheck)),
              trailing: Btn(
                t.checkNow,
                onPressed: u.busy ? null : () => u.check(),
              ),
            ),
          );
        }
        children.addAll([
          Item(
            label: t.autoUpdateCheck,
            trailing: Seg<bool>(
              options: {true: t.enabled, false: t.disabled},
              value: u.autoCheck,
              onChanged: u.setAutoCheck,
            ),
          ),
          CapItem(t.autoUpdateHint),
        ]);
        return Group(children: children);
      },
    );
  }
}

/// Release notes as plain text: Markdown marks removed, the download
/// instructions (for the web page) left out.
String releaseNotesText(String markdown) {
  final cut = markdown.indexOf(RegExp(r'^#+\s*Download', multiLine: true));
  final body = cut < 0 ? markdown : markdown.substring(0, cut);
  return body
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class _WhatsNew extends StatefulWidget {
  const _WhatsNew({required this.notes});
  final String notes;

  @override
  State<_WhatsNew> createState() => _WhatsNewState();
}

class _WhatsNewState extends State<_WhatsNew> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Item(
          label: context.tr.whatsNew,
          onTap: () => setState(() => _open = !_open),
          trailing: Icon(
            _open ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: c.text2,
          ),
        ),
        if (_open) CapItem(widget.notes),
      ],
    );
  }
}
