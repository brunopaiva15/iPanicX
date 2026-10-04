import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../models/device_status.dart';
import '../../models/diagnostic_file.dart';
import '../../models/scan_result.dart';
import '../../services/iphone_service.dart';
import '../../services/mock_iphone_service.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/device_card.dart';
import '../widgets/panic_card.dart';
import '../widgets/status_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppToolbar(
              title: 'iPaniX',
              subtitle: 'iPhone panic diagnostics · processed locally',
              actions: [
                if (app.iphone is MockIPhoneService)
                  _MockMenu(service: app.iphone as MockIPhoneService),
                TextButton.icon(
                  onPressed: () => openLocalIps(context),
                  icon: const Icon(Icons.file_open_outlined, size: 17),
                  label: const Text('Open .ips…'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'About iPaniX',
                  onPressed: () => showIPaniXAbout(context),
                  icon: const Icon(Icons.info_outline, size: 20),
                ),
              ],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                // Fill the area so pages start at the top (the default
                // layout centers its child).
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(app.status.state),
                  child: _body(context, app),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppController app) {
    final s = app.status;
    final colors = AppColors.of(context);
    switch (s.state) {
      case DeviceConnectionState.searching:
        return const Center(child: CircularProgressIndicator.adaptive());
      case DeviceConnectionState.noDevice:
        return const _StateView(
          icon: Icons.phone_iphone,
          title: 'No iPhone connected',
          message:
              'Connect an iPhone using USB.\n'
              'Unlock the device and tap “Trust” if asked.',
          showProgress: true,
        );
      case DeviceConnectionState.toolsUnavailable:
        return _StateView(
          icon: Icons.extension_off_outlined,
          color: colors.orange,
          title: 'libimobiledevice unavailable',
          message:
              '${s.message ?? ''}\n'
              'Install it with Homebrew, or build iPaniX with the bundled tools '
              '(see README).',
          code: 'brew install libimobiledevice',
          technical: s.technicalDetails,
          actions: [
            FilledButton(
              onPressed: app.retry,
              child: const Text('Check Again'),
            ),
          ],
        );
      case DeviceConnectionState.trustRequired:
        return _StateView(
          icon: Icons.verified_user_outlined,
          color: colors.orange,
          title: 'Trust required',
          message: s.message ?? 'Unlock your iPhone and tap “Trust” to allow this Mac to read diagnostics.',
          subtitle: s.device?.modelName,
          technical: s.technicalDetails,
          showProgress: true,
          actions: [
            FilledButton(
              onPressed: app.requestPairing,
              child: const Text('Show Trust Prompt'),
            ),
            OutlinedButton(onPressed: app.retry, child: const Text('Retry')),
          ],
        );
      case DeviceConnectionState.locked:
        return _StateView(
          icon: Icons.lock_outline,
          color: colors.orange,
          title: 'Device locked',
          message:
              s.message ??
              'Unlock your iPhone with its passcode, then try again.',
          technical: s.technicalDetails,
          showProgress: true,
          actions: [
            OutlinedButton(onPressed: app.retry, child: const Text('Retry')),
          ],
        );
      case DeviceConnectionState.communicationError:
        return _StateView(
          icon: Icons.usb_off,
          color: colors.red,
          title: 'Unable to communicate with iPhone',
          message:
              '${s.message ?? 'The iPhone did not respond correctly.'}\n'
              'Try another cable or USB port, and make sure the iPhone is unlocked.',
          technical: s.technicalDetails,
          actions: [
            FilledButton(onPressed: app.retry, child: const Text('Retry')),
          ],
        );
      case DeviceConnectionState.connected:
        return _ConnectedView(app: app);
    }
  }
}

// -----------------------------------------------------------------------------

class _ConnectedView extends StatelessWidget {
  const _ConnectedView({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final device = app.status.device!;
    final scan = app.scan;
    return PageBody(
      children: [
        if (app.status.hasMultipleDevices) ...[
          _Banner(
            icon: Icons.warning_amber_rounded,
            color: colors.orange,
            text:
                '${app.status.deviceCount} devices are connected. iPaniX is '
                'showing the first one. Disconnect the others to choose a device.',
          ),
          const SizedBox(height: 16),
        ],
        DeviceCard(
          device: device,
          action: _ScanButton(app: app),
        ),
        const SizedBox(height: 20),
        if (app.isScanning) _ScanProgress(app: app),
        if (app.phase == ScanPhase.failed && app.scanError != null)
          _ScanError(error: app.scanError!, onRetry: app.scanDiagnostics),
        if (scan != null && !app.isScanning) ...[
          _ScanSummary(scan: scan),
          if (scan.panics.isNotEmpty) ...[
            const SizedBox(height: 20),
            _RecentPanics(scan: scan),
          ],
        ],
        if (scan == null && !app.isScanning && app.phase != ScanPhase.failed)
          _Hint(
            icon: Icons.shield_outlined,
            text:
                'Scanning copies the crash reports to this Mac (they stay on '
                'the iPhone) and analyses them locally. Nothing is uploaded.',
          ),
      ],
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: app.isScanning ? null : app.scanDiagnostics,
      icon: app.isScanning
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.radar, size: 18),
      label: Text(app.scan == null ? 'Scan Diagnostics' : 'Scan Again'),
    );
  }
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final copying = app.phase == ScanPhase.copying;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copying ? 'Copying crash reports…' : 'Analyzing panics…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            copying
                ? (app.copiedFiles == 0
                      ? 'Keep the iPhone connected and unlocked.'
                      : '${plural(app.copiedFiles, 'file')} copied')
                : 'Parsing kernel panic reports on this Mac.',
            style: TextStyle(color: colors.secondaryText),
          ),
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 4),
        ],
      ),
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.error, required this.onRetry});
  final IPhoneServiceException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.kind.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(error.message, style: TextStyle(color: colors.secondaryText)),
          if (error.technicalDetails != null) ...[
            const SizedBox(height: 8),
            TechnicalDetails(details: error.technicalDetails!),
          ],
        ],
      ),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  const _ScanSummary({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cards = [
          _PanicSummaryCard(scan: scan),
          _HealthCard(health: scan.health),
        ];
        if (c.maxWidth < 720) {
          return Column(
            children: [cards[0], const SizedBox(height: 20), cards[1]],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 20),
              Expanded(child: cards[1]),
            ],
          ),
        );
      },
    );
  }
}

class _PanicSummaryCard extends StatelessWidget {
  const _PanicSummaryCard({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final latest = scan.latestPanic;
    final others = <String>[
      if (scan.countOf(DiagnosticFileType.jetsamEvent) > 0)
        plural(scan.countOf(DiagnosticFileType.jetsamEvent), 'Jetsam event'),
      if (scan.forcedResets.isNotEmpty)
        plural(scan.forcedResets.length, 'forced restart'),
      if (scan.countOf(DiagnosticFileType.resetCounter) > 0)
        plural(scan.countOf(DiagnosticFileType.resetCounter), 'reset counter'),
      if (scan.countOf(DiagnosticFileType.panicBase) > 0)
        plural(scan.countOf(DiagnosticFileType.panicBase), 'panic-base file'),
      '${plural(scan.files.length, 'file')} in total',
    ];
    return SectionCard(
      title: 'Kernel Panics',
      icon: Icons.bolt,
      trailing: TextButton(
        onPressed: () => AppRouter.openDevice(context),
        child: const Text('All files'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest == null) ...[
            Text(
              'No panic reports found',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'iPaniX copied ${plural(scan.files.length, 'diagnostic file')}, '
              'but none of them is a panic-full report.',
              style: TextStyle(color: colors.secondaryText),
            ),
          ] else ...[
            Text(
              plural(scan.panics.length, 'Kernel Panic'),
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 14),
            Text(
              'Latest',
              style: TextStyle(color: colors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              latest.file.name,
              style: monoStyle(context, size: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              formatRelativeDate(latest.date),
              style: TextStyle(color: colors.secondaryText, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => AppRouter.openPanic(context, latest),
              child: const Text('Analyze'),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            others.join(' · '),
            style: TextStyle(color: colors.tertiaryText, fontSize: 12),
          ),
          if (scan.unreadable.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${plural(scan.unreadable.length, 'panic file')} could not be read.',
                style: TextStyle(color: colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});
  final DeviceHealthSummary health;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final verdictColor = switch (health.verdict) {
      HealthVerdict.noPanics => colors.green,
      HealthVerdict.hardwareIssueLikely => colors.red,
      HealthVerdict.undetermined => colors.orange,
    };
    final verdictIcon = switch (health.verdict) {
      HealthVerdict.noPanics => Icons.check_circle_outline,
      HealthVerdict.hardwareIssueLikely => Icons.memory,
      HealthVerdict.undetermined => Icons.help_outline,
    };
    return SectionCard(
      title: 'Device Health',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            health.panicCount == 0
                ? 'No kernel panics detected'
                : '${plural(health.panicCount, 'kernel panic')} detected',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (health.mostCommonPanic != null) ...[
            Text(
              'Most common panic',
              style: TextStyle(color: colors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '${health.mostCommonPanic!}  (${health.mostCommonCount}×)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
          ],
          if (health.latest != null) ...[
            Text(
              'Latest',
              style: TextStyle(color: colors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              formatRelativeDate(health.latest),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
          ],
          if (health.forcedResetCount > 0) ...[
            Text(
              '${plural(health.forcedResetCount, 'forced restart')} (buttons held)',
              style: TextStyle(color: colors.secondaryText, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: verdictColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(verdictIcon, color: verdictColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  health.verdict.label,
                  style: TextStyle(
                    color: verdictColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPanics extends StatelessWidget {
  const _RecentPanics({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final shown = scan.panics.take(6).toList();
    return SectionCard(
      title: 'Recent Panics',
      icon: Icons.history,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      trailing: scan.panics.length > shown.length
          ? TextButton(
              onPressed: () => AppRouter.openDevice(context),
              child: Text('Show all ${scan.panics.length}'),
            )
          : null,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(indent: 12, endIndent: 12),
            PanicCard(
              panic: shown[i],
              onTap: () => AppRouter.openPanic(context, shown[i]),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
    this.subtitle,
    this.code,
    this.technical,
    this.actions = const [],
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? color;
  final String? subtitle;
  final String? code;
  final String? technical;
  final List<Widget> actions;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SectionCard(
            padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTile(icon: icon, color: color ?? colors.grey, size: 76),
                const SizedBox(height: 22),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(color: colors.secondaryText),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  message.trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.secondaryText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (code != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.codeBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: SelectableText(code!, style: monoStyle(context)),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Wrap(spacing: 10, runSpacing: 10, children: actions),
                ],
                if (showProgress) ...[
                  const SizedBox(height: 22),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waiting for device…',
                        style: TextStyle(
                          color: colors.tertiaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (technical != null && technical!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TechnicalDetails(details: technical!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.tertiaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.tertiaryText, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockMenu extends StatelessWidget {
  const _MockMenu({required this.service});
  final MockIPhoneService service;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopupMenuButton<MockScenario>(
      tooltip: 'Simulate a device state',
      initialValue: service.scenario,
      onSelected: service.setScenario,
      itemBuilder: (_) => [
        for (final s in MockScenario.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: StatusBadge(
          label: 'Mock device',
          color: colors.orange,
          icon: Icons.science_outlined,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// NSOpenPanel → parse → detail screen.
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
  final colors = AppColors.of(context);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: Icons.troubleshoot, color: colors.blue, size: 64),
            const SizedBox(height: 14),
            Text('iPaniX', style: Theme.of(context).textTheme.headlineSmall),
            Text(
              'Version 0.1.0 (V0)',
              style: TextStyle(color: colors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: colors.green, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'All diagnostic processing is performed locally on your Mac.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No analytics, no telemetry, no network requests. Crash reports '
              'are copied to a temporary folder on this Mac and never uploaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondaryText, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            InfoRow(
              label: 'Knowledge base',
              value:
                  'v${app.knowledgeBase.version ?? '?'} · ${plural(app.knowledgeBase.rules.length, 'signature')} (examples, not exhaustive)',
            ),
            InfoRow(
              label: 'Device backend',
              value: app.iphone.backendDescription,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
