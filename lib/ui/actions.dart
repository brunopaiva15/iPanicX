import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/host_platform.dart';
import '../app/router.dart';
import '../app/theme.dart';
import 'format.dart';
import 'widgets/common.dart';
import 'widgets/wordmark.dart';

/// File dialog (NSOpenPanel / Windows) → parse → detail screen.
///
/// [context] must be below the content navigator so the detail screen opens
/// in the content pane.
Future<void> openLocalIps(BuildContext context) async {
  final app = AppScope.read(context);
  final path = await app.bridge.pickIpsFile();
  if (!context.mounted) return;
  if (path == null) return;
  try {
    final panic = await app.diagnostics.analyzeLocalFile(path);
    if (!context.mounted) return;
    await AppRouter.openPanic(context, panic);
  } catch (e) {
    if (context.mounted) showMessage(context, 'This file could not be read.');
  }
}

void showIPaniXAbout(BuildContext context) {
  final app = AppScope.read(context);
  showDialog<void>(
    context: context,
    builder: (context) {
      final colors = AppColors.of(context);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 34, 30, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Wordmark(size: 30)),
                const SizedBox(height: 8),
                Text(
                  'Version 0.1.0 (V0)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, color: colors.ample, size: 18),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'All diagnostic processing is performed locally on your ${HostPlatform.computer}.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No analytics, no telemetry, no network requests. Crash '
                  'reports are copied to a temporary folder on this '
                  '${HostPlatform.computer} and never uploaded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.secondaryText,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                InfoRow(
                  padded: false,
                  label: 'Knowledge base',
                  value:
                      'v${app.knowledgeBase.version ?? '?'} · ${plural(app.knowledgeBase.rules.length, 'signature')} (examples, not exhaustive)',
                ),
                InfoRow(
                  padded: false,
                  label: 'Device backend',
                  value: app.iphone.backendDescription,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
