import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../app/theme.dart';
import '../../services/mock_iphone_service.dart';
import '../format.dart';
import '../kit.dart';

class GeneralPane extends StatelessWidget {
  const GeneralPane({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final mock = app.iphone is MockIPhoneService
        ? app.iphone as MockIPhoneService
        : null;
    return Pane(
      title: 'General',
      children: [
        Group(
          children: [
            Item(
              label: 'Appearance',
              trailing: Seg<ThemeMode>(
                options: const {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                },
                value: app.themeMode,
                onChanged: app.setThemeMode,
              ),
            ),
          ],
        ),
        if (mock != null) ...[
          const Sec('Simulated device'),
          Group(
            children: [
              Item(
                label: 'Scenario',
                hint: 'USE_MOCK_DEVICE is on',
                trailing: PopupMenuButton<MockScenario>(
                  tooltip: '',
                  initialValue: mock.scenario,
                  onSelected: mock.setScenario,
                  itemBuilder: (_) => [
                    for (final s in MockScenario.values)
                      PopupMenuItem(value: s, height: 32, child: Text(s.label)),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.segBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mock.scenario.label,
                          style: TextStyle(fontSize: 13, color: c.text),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.unfold_more, size: 14, color: c.text2),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const Sec('Privacy'),
        Group(
          children: [
            Item(
              leading: const Glyph(Icons.lock_outline),
              label:
                  'All diagnostic processing is performed locally on your ${HostPlatform.computer}.',
            ),
            CapItem(
              'No analytics, no telemetry, no network requests. Crash reports '
              'are copied to a temporary folder on this ${HostPlatform.computer} '
              'and never uploaded.',
            ),
          ],
        ),
        const Sec('About'),
        Group(
          children: [
            const Item(label: 'iPaniX', value: 'Version 0.1.0'),
            Item(
              label: 'Knowledge base',
              value:
                  'v${app.knowledgeBase.version ?? '?'} · ${plural(app.knowledgeBase.rules.length, 'signature')}',
            ),
            const CapItem(
              'The signatures are examples and do not cover every panic. '
              'A diagnosis should be confirmed by hardware inspection.',
            ),
            Item(
              label: 'Device backend',
              value: app.iphone.backendDescription,
              wrapValue: true,
            ),
          ],
        ),
      ],
    );
  }
}
