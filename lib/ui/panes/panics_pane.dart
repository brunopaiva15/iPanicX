import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../kit.dart';
import '../shell.dart';
import 'shared.dart';
import '../../l10n/lang_scope.dart';

class PanicsPane extends StatelessWidget {
  const PanicsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = AppScope.of(context).scan;
    final t = context.tr;
    if (scan == null) {
      return Pane(title: t.panicsSection, children: [const _NoScan()]);
    }
    return Pane(
      title: t.panicsSection,
      children: [
        Sec(t.kernelPanicsSection, first: true),
        Group(
          children: scan.panics.isEmpty
              ? [Item(label: t.noPanicReports)]
              : [for (final p in scan.panics) PanicItem(panic: p)],
        ),
        if (scan.forcedResets.isNotEmpty) ...[
          Sec(t.forcedRestartsSection),
          Group(
            children: [for (final p in scan.forcedResets) PanicItem(panic: p)],
          ),
        ],
      ],
    );
  }
}

class _NoScan extends StatelessWidget {
  const _NoScan();

  @override
  Widget build(BuildContext context) => Group(
    children: [
      Item(
        label: context.tr.noScanYet,
        hint: context.tr.noScanHint,
        trailing: Btn(
          context.tr.overview,
          onPressed: () => ShellScope.of(context).select(Section.overview),
        ),
      ),
    ],
  );
}

class NoScanGroup extends StatelessWidget {
  const NoScanGroup({super.key});

  @override
  Widget build(BuildContext context) => const _NoScan();
}
