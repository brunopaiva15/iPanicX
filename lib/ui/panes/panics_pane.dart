import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../kit.dart';
import '../shell.dart';
import 'shared.dart';

class PanicsPane extends StatelessWidget {
  const PanicsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = AppScope.of(context).scan;
    if (scan == null) {
      return Pane(title: 'Panics', children: [const _NoScan()]);
    }
    return Pane(
      title: 'Panics',
      children: [
        Sec('Kernel Panics', first: true),
        Group(
          children: scan.panics.isEmpty
              ? [const Item(label: 'No panic reports found')]
              : [for (final p in scan.panics) PanicItem(panic: p)],
        ),
        if (scan.forcedResets.isNotEmpty) ...[
          const Sec('Forced Restarts'),
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
        label: 'No scan yet',
        hint: 'Scan the connected iPhone from Overview.',
        trailing: Btn(
          'Overview',
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
