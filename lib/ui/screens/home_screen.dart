import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../models/device_status.dart';
import '../../models/diagnostic_file.dart';
import '../../models/scan_result.dart';
import '../../services/iphone_service.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/device_card.dart';
import '../widgets/panic_card.dart';
import '../widgets/ring.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        // Fill the area so pages start at the top (the default layout
        // centers its child).
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: KeyedSubtree(
          key: ValueKey(app.status.state),
          child: _body(context, app),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppController app) {
    final s = app.status;
    final colors = AppColors.of(context);
    switch (s.state) {
      case DeviceConnectionState.searching:
        return const _StateView(
          title: 'Looking for devices',
          message: 'Checking USB connections…',
          waiting: true,
        );
      case DeviceConnectionState.noDevice:
        return const _StateView(
          title: 'No iPhone connected',
          message:
              'Connect an iPhone using USB.\n'
              'Unlock the device and tap “Trust” if asked.',
          waiting: true,
        );
      case DeviceConnectionState.toolsUnavailable:
        return _StateView(
          icon: Icons.extension_off_rounded,
          color: colors.critical,
          title: 'libimobiledevice unavailable',
          message: '${s.message ?? ''}\n${HostPlatform.installHint}',
          code: HostPlatform.installCommand,
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
          icon: Icons.verified_user_rounded,
          color: colors.watch,
          fill: 0.5,
          title: 'Trust required',
          message:
              s.message ??
              'Unlock your iPhone and tap “Trust” to allow this ${HostPlatform.computer} to read diagnostics.',
          subtitle: s.device?.modelName,
          technical: s.technicalDetails,
          waitingNote: true,
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
          icon: Icons.lock_rounded,
          color: colors.watch,
          fill: 0.5,
          title: 'Device locked',
          message:
              s.message ??
              'Unlock your iPhone with its passcode, then try again.',
          technical: s.technicalDetails,
          waitingNote: true,
          actions: [
            OutlinedButton(onPressed: app.retry, child: const Text('Retry')),
          ],
        );
      case DeviceConnectionState.communicationError:
        return _StateView(
          icon: Icons.usb_off_rounded,
          color: colors.critical,
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
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: AppToolbar(
            eyebrow: 'Overview',
            title: 'Device diagnostics',
            subtitle: 'Kernel panics read from the connected iPhone',
          ),
        ),
        SliverToBoxAdapter(
          child: PageBody(
            children: [
              if (app.status.hasMultipleDevices) ...[
                _Banner(
                  icon: Icons.warning_amber_rounded,
                  color: colors.watch,
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
                const SizedBox(height: 20),
                _HealthCard(scan: scan),
                if (scan.panics.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  _RecentPanics(scan: scan),
                ],
              ],
              if (scan == null &&
                  !app.isScanning &&
                  app.phase != ScanPhase.failed)
                _Hint(
                  icon: Icons.lock_rounded,
                  text:
                      'Scanning copies the crash reports to this ${HostPlatform.computer} (they stay on '
                      'the iPhone) and analyses them locally. Nothing is uploaded.',
                ),
            ],
          ),
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
          : const Icon(Icons.radar_rounded, size: 18),
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
      child: Row(
        children: [
          UsageRing(
            fraction: 0.25,
            color: colors.ample,
            size: 48,
            stroke: 4,
            spinning: true,
            child: Icon(
              copying ? Icons.download_rounded : Icons.manage_search_rounded,
              size: 19,
              color: colors.ink,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copying ? 'Copying crash reports…' : 'Analyzing panics…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  copying
                      ? (app.copiedFiles == 0
                            ? 'Keep the iPhone connected and unlocked.'
                            : '${plural(app.copiedFiles, 'file')} copied')
                      : 'Parsing kernel panic reports on this ${HostPlatform.computer}.',
                  style: TextStyle(color: colors.secondaryText),
                ),
              ],
            ),
          ),
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
              UsageRing(
                fraction: 1,
                color: colors.critical,
                size: 40,
                stroke: 3.5,
                child: Icon(
                  Icons.priority_high_rounded,
                  size: 18,
                  color: colors.ink,
                ),
              ),
              const SizedBox(width: 14),
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
          const SizedBox(height: 10),
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

/// Kernel panic count + the black "notch" of rings.
class _ScanSummary extends StatelessWidget {
  const _ScanSummary({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final left = _PanicSummaryCard(scan: scan);
        final right = _NotchStrip(scan: scan);
        if (c.maxWidth < 760) {
          return Column(children: [left, const SizedBox(height: 20), right]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: left),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: right),
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
      '${plural(scan.files.length, 'file')} in total',
    ];
    return SectionCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Kernel panics'),
          const SizedBox(height: 12),
          if (latest == null) ...[
            Text(
              'No panic reports found',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'iPaniX copied ${plural(scan.files.length, 'diagnostic file')}, '
              'but none of them is a kernel panic report.',
              style: TextStyle(color: colors.secondaryText),
            ),
          ] else ...[
            Text(
              plural(scan.panics.length, 'Kernel Panic'),
              style: numeralStyle(context, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              'Latest',
              style: TextStyle(color: colors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              latest.file.name,
              style: monoStyle(context, size: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              formatRelativeDate(latest.date),
              style: TextStyle(color: colors.secondaryText, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => AppRouter.openPanic(context, latest),
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('Analyze'),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            others.join(' · '),
            style: TextStyle(color: colors.tertiaryText, fontSize: 12),
          ),
          if (scan.unreadable.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${plural(scan.unreadable.length, 'panic file')} could not be read.',
                style: TextStyle(color: colors.watch, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Always-black pill with three rings, like Codenotch's notch.
class _NotchStrip extends StatelessWidget {
  const _NotchStrip({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final n = scan.panics.length;
    final known = scan.panics.where((p) => p.result.isKnownSignature).length;
    final hardware = scan.panics
        .where((p) => p.result.isHardwareRelated)
        .length;
    final top = scan.health.mostCommonCount;
    double share(int k) => n == 0 ? 0 : k / n;
    return Theme(
      data: buildTheme(Brightness.dark),
      child: Builder(
        builder: (context) {
          final colors = AppColors.of(context);
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RingStat(
                        fraction: share(known),
                        color: colors.ample,
                        icon: Icons.fact_check_rounded,
                        label: 'Known signature',
                      ),
                    ),
                    Expanded(
                      child: RingStat(
                        fraction: share(hardware),
                        color: colors.band(share(hardware)),
                        icon: Icons.memory_rounded,
                        label: 'Hardware-related',
                      ),
                    ),
                    Expanded(
                      child: RingStat(
                        fraction: share(top),
                        color: colors.blue,
                        icon: Icons.repeat_rounded,
                        label: 'Same signature',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  n == 0
                      ? 'No kernel panics to measure.'
                      : 'Shares of the $n kernel panics found — not a health score.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.secondaryText, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tooltip-card style summary: signature bars, facts, verdict.
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final health = scan.health;
    final verdictColor = switch (health.verdict) {
      HealthVerdict.noPanics => colors.ample,
      HealthVerdict.hardwareIssueLikely => colors.critical,
      HealthVerdict.undetermined => colors.watch,
    };

    // Signature distribution, same grouping as the health summary.
    final counts = <String, (int, AnalyzedPanic)>{};
    for (final p in scan.panics) {
      final key = p.result.isKnownSignature
          ? p.result.title
          : (p.report.signature ?? p.result.title);
      final prev = counts[key];
      counts[key] = ((prev?.$1 ?? 0) + 1, prev?.$2 ?? p);
    }
    final groups = counts.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    return SectionCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, size: 20, color: colors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Device Health',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: verdictColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  health.verdict.label,
                  style: TextStyle(
                    color: colors.onSignal,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            health.panicCount == 0
                ? 'No kernel panics detected'
                : '${plural(health.panicCount, 'kernel panic')} detected',
            style: TextStyle(color: colors.secondaryText, fontSize: 13),
          ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final g in groups.take(3)) ...[
              BarRow(
                label: g.key,
                trailing: formatRelativeDate(g.value.$2.date),
                fraction: g.value.$1 / health.panicCount,
                color:
                    colors.severity(g.value.$2.result.severity) == colors.grey
                    ? colors.blue
                    : colors.severity(g.value.$2.result.severity),
                caption:
                    '${plural(g.value.$1, 'panic')} · ${(100 * g.value.$1 / health.panicCount).round()}%',
              ),
              const SizedBox(height: 16),
            ],
          ],
          const SizedBox(height: 4),
          Divider(color: colors.hairline),
          const SizedBox(height: 12),
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              if (health.mostCommonPanic != null)
                _Fact(
                  label: 'Most common panic',
                  value:
                      '${health.mostCommonPanic!}  (${health.mostCommonCount}×)',
                ),
              if (health.latest != null)
                _Fact(
                  label: 'Latest',
                  value: formatRelativeDate(health.latest),
                ),
              if (health.forcedResetCount > 0)
                _Fact(
                  label: 'Forced restarts',
                  value:
                      '${plural(health.forcedResetCount, 'forced restart')} (buttons held)',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: SectionLabel('Recent Panics'),
            ),
            const Spacer(),
            if (scan.panics.length > shown.length)
              TextButton(
                onPressed: () => AppRouter.openDevice(context),
                child: Text('Show all ${scan.panics.length}'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Group(
          children: [
            for (final p in shown)
              PanicCard(panic: p, onTap: () => AppRouter.openPanic(context, p)),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

/// Centered state: a big ring around a glyph, title, message, actions.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.title,
    required this.message,
    this.icon = Icons.phone_iphone_rounded,
    this.color,
    this.fill = 1,
    this.subtitle,
    this.code,
    this.technical,
    this.actions = const [],
    this.waiting = false,
    this.waitingNote = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? color;
  final double fill;
  final String? subtitle;
  final String? code;
  final String? technical;
  final List<Widget> actions;

  /// Spinning ring (looking for a device).
  final bool waiting;

  /// "Waiting for device…" line under the actions.
  final bool waitingNote;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UsageRing(
                fraction: waiting ? 0 : fill,
                color: color ?? colors.grey,
                size: 128,
                stroke: 8,
                spinning: waiting,
                child: Icon(icon, size: 48, color: colors.ink),
              ),
              const SizedBox(height: 30),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 28),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: TextStyle(color: colors.secondaryText)),
              ],
              const SizedBox(height: 12),
              Text(
                message.trim(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.secondaryText,
                  fontSize: 14.5,
                  height: 1.55,
                ),
              ),
              if (code != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: SelectableText(code!, style: monoStyle(context)),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 26),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
              if (waitingNote) ...[
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UsageRing(
                      fraction: 0.3,
                      color: colors.secondaryText,
                      size: 14,
                      stroke: 1.8,
                      spinning: true,
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
                const SizedBox(height: 18),
                TechnicalDetails(details: technical!),
              ],
            ],
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
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
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
          Icon(icon, size: 15, color: colors.ample),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.secondaryText, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
