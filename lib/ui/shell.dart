import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/theme.dart';
import '../models/device_status.dart';
import '../models/scan_result.dart';
import 'kit.dart';
import 'panes/files_pane.dart';
import 'panes/general_pane.dart';
import 'panes/overview_pane.dart';
import 'panes/panic_pane.dart';
import 'panes/panics_pane.dart';
import '../l10n/lang_scope.dart';

enum Section { overview, panics, files, general }

/// Navigation for the panes: a section from the sidebar, optionally a panic
/// opened on top of it (and its raw report).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.state, required super.child});

  final AppShellState state;

  static AppShellState of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellScope>()!.state;

  @override
  bool updateShouldNotify(ShellScope old) => false;
}

/// Codenotch's settings window layout: an inset sidebar card and a pane.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  Section _section = Section.overview;
  AnalyzedPanic? _panic;
  bool _raw = false;
  DeviceConnectionState? _lastState;

  void select(Section s) => setState(() {
    _section = s;
    _panic = null;
    _raw = false;
  });

  void openPanic(AnalyzedPanic p) => setState(() {
    _panic = p;
    _raw = false;
  });

  void openRaw() => setState(() => _raw = true);

  void back() => setState(() {
    if (_raw) {
      _raw = false;
    } else {
      _panic = null;
    }
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A panic from a scan belongs to the device that was connected.
    final state = AppScope.of(context).status.state;
    if (_lastState == DeviceConnectionState.connected &&
        state != DeviceConnectionState.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) select(Section.overview);
      });
    }
    _lastState = state;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final Widget pane = _panic != null
        ? (_raw ? RawPane(panic: _panic!) : PanicPane(panic: _panic!))
        : switch (_section) {
            Section.overview => const OverviewPane(),
            Section.panics => const PanicsPane(),
            Section.files => const FilesPane(),
            Section.general => const GeneralPane(),
          };
    return ShellScope(
      state: this,
      child: Scaffold(
        backgroundColor: c.background,
        body: ColoredBox(
          color: c.pane,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(section: _section, onSelect: select),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('$_section/${_panic?.file.path}/$_raw'),
                  child: pane,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `#side`: 196px card inset 4px, radius 14, 48px band, rows of 32px.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.section, required this.onSelect});

  final Section section;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = context.tr;
    return Container(
      width: 196,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: c.side,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          _Row(
            badge: const SideBadge(Icons.phone_iphone, SideBadge.blue),
            label: t.overview,
            selected: section == Section.overview,
            onTap: () => onSelect(Section.overview),
          ),
          _Row(
            badge: const SideBadge(Icons.bolt, SideBadge.red),
            label: t.panicsSection,
            selected: section == Section.panics,
            onTap: () => onSelect(Section.panics),
          ),
          _Row(
            badge: const SideBadge(Icons.folder, SideBadge.gray),
            label: t.filesSection,
            selected: section == Section.files,
            onTap: () => onSelect(Section.files),
          ),
          _Row(
            badge: const SideBadge(Icons.settings, SideBadge.indigo),
            label: t.general,
            selected: section == Section.general,
            onTap: () => onSelect(Section.general),
          ),
          const Spacer(),
          _Row(
            badge: const SideBadge(Icons.description, SideBadge.gray),
            label: t.openIps,
            onTap: () => openLocalIps(context),
          ),
        ],
      ),
    );
  }
}

/// Header of the sidebar: app logo and name, in the 48px top band.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 6),
        child: Row(
          children: [
            Image.asset(
              'assets/branding/logo_256.png',
              width: 30,
              height: 30,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'iPanicX',
            ),
            const SizedBox(width: 9),
            Text(
              'iPanicX',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.row`: 32px, radius 8, gap 9; selected: soft fill + 3px accent bar.
class _Row extends StatefulWidget {
  const _Row({
    required this.badge,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final Widget badge;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? c.selSoft
                  : (_hover ? c.hover : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                if (widget.selected)
                  Positioned(
                    left: -8,
                    top: 9,
                    bottom: 9,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    widget.badge,
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: kBodySize, color: c.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// File dialog → parse → panic pane.
Future<void> openLocalIps(BuildContext context) async {
  final app = AppScope.read(context);
  final shell = ShellScope.of(context);
  final path = await app.bridge.pickIpsFile();
  if (path == null || !context.mounted) return;
  try {
    shell.openPanic(await app.diagnostics.analyzeLocalFile(path));
  } catch (_) {
    if (context.mounted) showToast(context, context.tr.fileUnreadable);
  }
}
