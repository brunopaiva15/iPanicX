import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/host_platform.dart';
import '../app/router.dart';
import '../app/theme.dart';
import '../models/device_status.dart';
import '../services/mock_iphone_service.dart';
import 'actions.dart';
import 'widgets/ring.dart';
import 'widgets/status_badge.dart';
import 'widgets/wordmark.dart';

/// Window layout: sidebar (device, navigation) + content pane hosting a
/// nested navigator, in the spirit of Codenotch's settings window.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _tracker = _RouteTracker(_onRouteChanged);
  String _route = AppRouter.home;

  void _onRouteChanged(String? name) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && name != null && name != _route) {
        setState(() => _route = name);
      }
    });
  }

  DeviceConnectionState? _lastState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When the device goes away (or changes state) while a scan screen is
    // open, return to the overview: its data no longer belongs to a
    // connected device.
    final state = AppScope.of(context).status.state;
    if (_lastState == DeviceConnectionState.connected &&
        state != DeviceConnectionState.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
    }
    _lastState = state;
  }

  void _goHome() =>
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);

  void _goFiles() {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    nav.pushNamed(AppRouter.device);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.window,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            route: _route,
            onOverview: _goHome,
            onFiles: _goFiles,
            navigatorKey: _navigatorKey,
          ),
          Expanded(
            child: ClipRect(
              child: Navigator(
                key: _navigatorKey,
                observers: [_tracker],
                initialRoute: AppRouter.home,
                onGenerateRoute: AppRouter.onGenerateRoute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTracker extends NavigatorObserver {
  _RouteTracker(this.onChange);
  final void Function(String?) onChange;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange(route.settings.name);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange(previousRoute?.settings.name);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChange(newRoute?.settings.name);
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.route,
    required this.onOverview,
    required this.onFiles,
    required this.navigatorKey,
  });

  final String route;
  final VoidCallback onOverview;
  final VoidCallback onFiles;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final colors = AppColors.of(context);
    final scan = app.scan;
    // Actions that push screens must use the content navigator's context.
    BuildContext navContext() => navigatorKey.currentContext ?? context;
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(right: BorderSide(color: colors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Wordmark(size: 21),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 8, 0),
            child: Text(
              'iPhone panic diagnostics',
              style: TextStyle(color: colors.secondaryText, fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 22),
          _DeviceChip(status: app.status),
          const SizedBox(height: 22),
          _NavItem(
            icon: Icons.space_dashboard_rounded,
            label: 'Overview',
            selected: route == AppRouter.home,
            onTap: onOverview,
          ),
          _NavItem(
            icon: Icons.folder_rounded,
            label: 'Diagnostic Files',
            selected: route == AppRouter.device,
            enabled: scan != null,
            badge: scan == null ? null : '${scan.files.length}',
            onTap: onFiles,
          ),
          _NavItem(
            icon: Icons.file_open_rounded,
            label: 'Open .ips…',
            onTap: () => openLocalIps(navContext()),
          ),
          Tooltip(
            message: 'About iPaniX',
            child: _NavItem(
              icon: Icons.info_outline_rounded,
              label: 'About',
              onTap: () => showIPaniXAbout(context),
            ),
          ),
          const Spacer(),
          _AppearancePicker(mode: app.themeMode, onChanged: app.setThemeMode),
          const SizedBox(height: 12),
          if (app.iphone is MockIPhoneService) ...[
            _MockMenu(service: app.iphone as MockIPhoneService),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 15, color: colors.ample),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Processed locally on this ${HostPlatform.computer}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.secondaryText,
                    ),
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

/// Device summary at the top of the sidebar: ring coloured by state.
class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.status});

  final DeviceStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final d = status.device;
    final (
      Color color,
      double fill,
      String title,
      String subtitle,
    ) = switch (status.state) {
      DeviceConnectionState.searching => (
        colors.grey,
        0.0,
        'Looking for devices',
        'USB',
      ),
      DeviceConnectionState.noDevice => (
        colors.grey,
        0.0,
        'No iPhone',
        'Connect via USB',
      ),
      DeviceConnectionState.connected => (
        colors.ample,
        1.0,
        d?.displayName ?? 'iPhone',
        [
          'USB',
          if (d?.productVersion != null) 'iOS ${d!.productVersion}',
        ].join(' · '),
      ),
      DeviceConnectionState.trustRequired => (
        colors.watch,
        0.5,
        d?.modelName ?? 'iPhone',
        'Awaiting trust',
      ),
      DeviceConnectionState.locked => (
        colors.watch,
        0.5,
        d?.modelName ?? 'iPhone',
        'Locked',
      ),
      DeviceConnectionState.communicationError => (
        colors.critical,
        1.0,
        d?.modelName ?? 'iPhone',
        'Not responding',
      ),
      DeviceConnectionState.toolsUnavailable => (
        colors.critical,
        1.0,
        'Tools missing',
        'libimobiledevice',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          UsageRing(
            fraction: fill,
            color: color,
            size: 42,
            stroke: 3.5,
            spinning:
                status.state == DeviceConnectionState.searching ||
                status.state == DeviceConnectionState.noDevice,
            child: Icon(
              Icons.phone_iphone_rounded,
              size: 18,
              color: colors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.secondaryText, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;
  final String? badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fg = !widget.enabled
        ? colors.tertiaryText
        : widget.selected
        ? colors.ink
        : colors.secondaryText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.raised
                  : _hover && widget.enabled
                  ? colors.raised.withValues(alpha: 0.55)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: widget.selected ? colors.border : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 17, color: fg),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: fg,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.badge != null)
                  Text(
                    widget.badge!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.secondaryText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
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
      child: StatusBadge(
        label: 'Mock device · ${service.scenario.label}',
        color: colors.watch,
      ),
    );
  }
}

/// Dark / System / Light segmented control.
class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget seg(ThemeMode m, IconData icon, String tip) {
      final selected = m == mode;
      return Expanded(
        child: Tooltip(
          message: tip,
          child: GestureDetector(
            onTap: () => onChanged(m),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? colors.raised : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? colors.border : Colors.transparent,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: selected ? colors.ink : colors.secondaryText,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          seg(ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
          seg(ThemeMode.system, Icons.contrast_rounded, 'Match system'),
          seg(ThemeMode.light, Icons.light_mode_rounded, 'Light'),
        ],
      ),
    );
  }
}
