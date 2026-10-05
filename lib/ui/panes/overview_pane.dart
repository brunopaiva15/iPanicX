import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../app/theme.dart';
import '../../models/device_status.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import '../kit.dart';
import '../ring.dart';
import '../shell.dart';
import 'shared.dart';

class OverviewPane extends StatelessWidget {
  const OverviewPane({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.status;
    return Pane(
      title: 'Overview',
      children: switch (s.state) {
        DeviceConnectionState.connected => _connected(context, app),
        _ => _disconnected(context, app),
      },
    );
  }

  List<Widget> _disconnected(BuildContext context, AppController app) {
    final s = app.status;
    final c = AppColors.of(context);
    final spinner = UsageRing(
      size: 16,
      fraction: 0,
      color: c.text2,
      track: c.segBg,
      spinning: true,
    );
    return switch (s.state) {
      DeviceConnectionState.searching => [
        Group(
          children: [Item(leading: spinner, label: 'Looking for devices…')],
        ),
      ],
      DeviceConnectionState.noDevice => [
        Group(
          children: [
            Item(leading: spinner, label: 'No iPhone connected'),
            const CapItem(
              'Connect an iPhone using USB.\n'
              'Unlock the device and tap “Trust” if asked.',
            ),
          ],
        ),
      ],
      DeviceConnectionState.trustRequired => [
        Group(
          children: [
            Item(
              leading: spinner,
              label: 'Trust required',
              hint: s.device?.modelName,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Btn('Retry', onPressed: app.retry),
                  const SizedBox(width: 8),
                  Btn(
                    'Show Trust Prompt',
                    primary: true,
                    onPressed: app.requestPairing,
                  ),
                ],
              ),
            ),
            CapItem(
              s.message ??
                  'Unlock your iPhone and tap “Trust” to allow this ${HostPlatform.computer} to read diagnostics.',
            ),
            if (s.technicalDetails != null)
              TechnicalDetails(details: s.technicalDetails!),
          ],
        ),
      ],
      DeviceConnectionState.locked => [
        Group(
          children: [
            Item(
              leading: spinner,
              label: 'Device locked',
              trailing: Btn('Retry', onPressed: app.retry),
            ),
            CapItem(
              s.message ??
                  'Unlock your iPhone with its passcode, then try again.',
            ),
            if (s.technicalDetails != null)
              TechnicalDetails(details: s.technicalDetails!),
          ],
        ),
      ],
      DeviceConnectionState.communicationError => [
        Group(
          children: [
            Item(
              leading: Glyph(Icons.usb_off, color: c.danger),
              label: 'Unable to communicate with iPhone',
              trailing: Btn('Retry', onPressed: app.retry),
            ),
            CapItem(
              '${s.message ?? 'The iPhone did not respond correctly.'}\n'
              'Try another cable or USB port, and make sure the iPhone is unlocked.',
            ),
            if (s.technicalDetails != null)
              TechnicalDetails(details: s.technicalDetails!),
          ],
        ),
      ],
      DeviceConnectionState.toolsUnavailable => [
        Group(
          children: [
            Item(
              leading: Glyph(Icons.extension_off, color: c.danger),
              label: 'libimobiledevice unavailable',
              trailing: Btn('Check Again', onPressed: app.retry),
            ),
            CapItem(HostPlatform.installHint),
            CapItem(HostPlatform.installCommand, mono: true),
            if (s.technicalDetails != null)
              TechnicalDetails(details: s.technicalDetails!),
          ],
        ),
      ],
      DeviceConnectionState.connected => const [],
    };
  }

  List<Widget> _connected(BuildContext context, AppController app) {
    final c = AppColors.of(context);
    final d = app.status.device!;
    final scan = app.scan;
    return [
      if (app.status.hasMultipleDevices)
        _Strip(
          '${app.status.deviceCount} devices are connected. iPaniX is showing '
          'the first one. Disconnect the others to choose a device.',
        ),
      Group(
        children: [
          Item(
            leading: const Glyph(Icons.phone_iphone),
            label: d.displayName,
            value: 'Connected via USB',
          ),
          Item(label: 'Model', value: d.modelName),
          Item(label: 'Product type', value: d.productType, mono: true),
          Item(label: 'iOS', value: d.productVersion),
          Item(label: 'Build', value: d.buildVersion, mono: true),
          Item(label: 'UDID', value: d.maskedUdid, mono: true),
        ],
      ),
      const Sec('Diagnostics'),
      Group(
        children: [
          Item(
            label: 'Scan diagnostics',
            hint:
                'Copies the crash reports to this ${HostPlatform.computer}. '
                'They stay on the iPhone.',
            trailing: app.isScanning
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UsageRing(
                        size: 16,
                        fraction: 0,
                        color: c.text2,
                        track: c.segBg,
                        spinning: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        app.phase == ScanPhase.analyzing
                            ? 'Analyzing…'
                            : app.copiedFiles == 0
                            ? 'Copying…'
                            : 'Copying… ${plural(app.copiedFiles, 'file')}',
                        style: TextStyle(fontSize: kBodySize, color: c.text2),
                      ),
                    ],
                  )
                : Btn(
                    scan == null ? 'Scan Diagnostics' : 'Scan Again',
                    primary: scan == null,
                    onPressed: app.scanDiagnostics,
                  ),
          ),
          if (app.phase == ScanPhase.failed && app.scanError != null) ...[
            Item(
              leading: Glyph(Icons.error_outline, color: c.danger),
              label: app.scanError!.kind.title,
              hint: app.scanError!.message,
            ),
            if (app.scanError!.technicalDetails != null)
              TechnicalDetails(details: app.scanError!.technicalDetails!),
          ],
        ],
      ),
      if (scan != null && !app.isScanning) ..._results(context, scan),
    ];
  }

  List<Widget> _results(BuildContext context, ScanResult scan) {
    final c = AppColors.of(context);
    final shell = ShellScope.of(context);
    final h = scan.health;
    if (scan.panics.isEmpty) {
      return [
        const Sec('Kernel Panics'),
        Group(
          children: [
            Item(
              label: 'No panic reports found',
              hint:
                  '${plural(scan.files.length, 'diagnostic file')} copied, none of '
                  'them is a kernel panic report.',
              trailing: Btn(
                'Show Files',
                onPressed: () => shell.select(Section.files),
              ),
            ),
          ],
        ),
      ];
    }
    final latest = scan.latestPanic!;
    final health = Group(
      children: [
        Item(
          label: 'Device Health',
          value: h.verdict.label,
          valueColor: h.verdict == HealthVerdict.hardwareIssueLikely
              ? c.danger
              : null,
        ),
        Item(label: 'Kernel panics', value: '${h.panicCount}'),
        if (h.mostCommonPanic != null)
          Item(
            label: 'Most common',
            value: '${h.mostCommonPanic!}  (${h.mostCommonCount}×)',
          ),
        Item(label: 'Latest', value: formatRelativeDate(h.latest)),
        if (h.forcedResetCount > 0)
          Item(label: 'Forced restarts', value: '${h.forcedResetCount}'),
        Item(
          label: 'Latest report',
          hint: latest.file.name,
          trailing: Btn(
            'Analyze',
            primary: true,
            onPressed: () => shell.openPanic(latest),
          ),
        ),
      ],
    );
    return [
      const Sec('Kernel Panics'),
      health,
      const Sec('Recent'),
      Group(
        children: [
          for (final p in scan.panics.take(5)) PanicItem(panic: p),
          if (scan.panics.length > 5)
            Item(
              label: 'Show all ${scan.panics.length}',
              trailing: Icon(Icons.chevron_right, size: 16, color: c.text3),
              onTap: () => shell.select(Section.panics),
            ),
        ],
      ),
    ];
  }
}

/// `#strip`: the settings window's one notice style.
class _Strip extends StatelessWidget {
  const _Strip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.dangerBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: c.danger)),
    );
  }
}
