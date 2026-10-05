import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../app/theme.dart';
import '../../l10n/lang_scope.dart';
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
      title: context.tr.overview,
      children: switch (s.state) {
        DeviceConnectionState.connected => _connected(context, app),
        _ => _disconnected(context, app),
      },
    );
  }

  List<Widget> _disconnected(BuildContext context, AppController app) {
    final s = app.status;
    final c = AppColors.of(context);
    final t = context.tr;
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
          children: [Item(leading: spinner, label: t.lookingForDevices)],
        ),
      ],
      DeviceConnectionState.noDevice => [
        Group(
          children: [
            Item(
              leading: const Glyph(Icons.phone_iphone),
              label: t.noIPhone,
              trailing: Btn(t.checkAgain, onPressed: app.retry),
            ),
            CapItem(t.noIPhoneHelp),
            if (s.technicalDetails != null)
              TechnicalDetails(details: s.technicalDetails!),
          ],
        ),
        Sec(t.notDetectedSection),
        Group(
          children: [CapItem(t.cableTips), CapItem(HostPlatform.driverHint)],
        ),
      ],
      DeviceConnectionState.notRecognized => [
        Group(
          children: [
            Item(
              leading: Glyph(Icons.usb, color: c.danger),
              label: t.notRecognized,
              trailing: Btn(t.checkAgain, onPressed: app.retry),
            ),
            CapItem(
              s.reason == StatusReason.driverProblem
                  ? HostPlatform.driverProblemHint
                  : HostPlatform.notRecognizedHint,
            ),
            if (s.technicalDetails != null)
              TechnicalDetails(details: s.technicalDetails!),
          ],
        ),
      ],
      DeviceConnectionState.trustRequired => [
        Group(
          children: [
            Item(
              leading: spinner,
              label: t.trustRequired,
              hint: s.device?.modelName,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Btn(t.retry, onPressed: app.retry),
                  const SizedBox(width: 8),
                  Btn(
                    t.showTrustPrompt,
                    primary: true,
                    onPressed: app.requestPairing,
                  ),
                ],
              ),
            ),
            CapItem(
              s.reason == StatusReason.pairingDenied
                  ? t.pairingDenied
                  : t.trustHelp(HostPlatform.computer),
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
              label: t.deviceLocked,
              trailing: Btn(t.retry, onPressed: app.retry),
            ),
            CapItem(t.lockedHelp),
            if (s.technicalDetails != null)
              TechnicalDetails(details: s.technicalDetails!),
          ],
        ),
      ],
      DeviceConnectionState.communicationError
          when s.reason == StatusReason.usbServiceUnavailable =>
        [
          Group(
            children: [
              Item(
                leading: Glyph(Icons.usb_off, color: c.danger),
                label: HostPlatform.usbServiceTitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Btn(t.retry, onPressed: app.retry),
                    if (HostPlatform.isWindows) ...[
                      const SizedBox(width: 8),
                      Btn(
                        t.openStore,
                        primary: true,
                        onPressed: app.bridge.openAppleDevicesInStore,
                      ),
                    ],
                  ],
                ),
              ),
              CapItem(HostPlatform.usbServiceSteps),
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
              label: t.commError,
              trailing: Btn(t.retry, onPressed: app.retry),
            ),
            CapItem(switch (s.reason) {
              StatusReason.timeout when s.udid == null => t.lookupTimeoutHelp,
              StatusReason.timeout => t.timeoutHelp,
              _ => t.commHelp,
            }),
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
              label: t.toolsUnavailable,
              trailing: Btn(t.checkAgain, onPressed: app.retry),
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
    final t = context.tr;
    final d = app.status.device!;
    final scan = app.scan;
    return [
      if (app.status.hasMultipleDevices)
        _Strip(t.multipleDevices(app.status.deviceCount)),
      Group(
        children: [
          Item(
            leading: const Glyph(Icons.phone_iphone),
            label: d.displayName,
            value: t.connectedViaUsb,
          ),
          Item(label: t.model, value: d.modelName),
          Item(label: t.productType, value: d.productType, mono: true),
          Item(label: 'iOS', value: d.productVersion),
          Item(label: t.build, value: d.buildVersion, mono: true),
          Item(label: 'UDID', value: d.maskedUdid, mono: true),
        ],
      ),
      Sec(t.diagnostics),
      Group(
        children: [
          Item(
            label: t.scanDiagnostics,
            hint: t.scanHint(HostPlatform.computer),
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
                            ? t.analyzing
                            : app.copiedFiles == 0
                            ? t.copying
                            : t.copyingFiles(app.copiedFiles),
                        style: TextStyle(fontSize: kBodySize, color: c.text2),
                      ),
                    ],
                  )
                : Btn(
                    scan == null ? t.scanButton : t.scanAgain,
                    primary: scan == null,
                    onPressed: app.scanDiagnostics,
                  ),
          ),
          if (app.phase == ScanPhase.failed && app.scanError != null) ...[
            Item(
              leading: Glyph(Icons.error_outline, color: c.danger),
              label: app.scanError!.kind.title,
              hint: app.scanError!.kind.message,
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
    final t = context.tr;
    final shell = ShellScope.of(context);
    final h = scan.health;
    if (scan.panics.isEmpty) {
      return [
        Sec(t.kernelPanicsSection),
        Group(
          children: [
            Item(
              label: t.noPanicReports,
              hint: t.noPanicReportsHint(scan.files.length),
              trailing: Btn(
                t.showFiles,
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
          label: t.deviceHealth,
          value: h.verdict.label,
          valueColor: h.verdict == HealthVerdict.hardwareIssueLikely
              ? c.danger
              : null,
        ),
        Item(label: t.kernelPanicsLabel, value: '${h.panicCount}'),
        if (h.mostCommonPanic != null)
          Item(
            label: t.mostCommon,
            value: '${h.mostCommonPanic!}  (${h.mostCommonCount}×)',
          ),
        Item(label: t.latest, value: formatRelativeDate(h.latest)),
        if (h.forcedResetCount > 0)
          Item(label: t.forcedRestarts, value: '${h.forcedResetCount}'),
        Item(
          label: t.latestReport,
          hint: latest.file.name,
          trailing: Btn(
            t.analyze,
            primary: true,
            onPressed: () => shell.openPanic(latest),
          ),
        ),
      ],
    );
    return [
      Sec(t.kernelPanicsSection),
      health,
      Sec(t.recent),
      Group(
        children: [
          for (final p in scan.panics.take(5)) PanicItem(panic: p),
          if (scan.panics.length > 5)
            Item(
              label: t.showAll(scan.panics.length),
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
