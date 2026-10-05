import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/host_platform.dart';
import '../../app/theme.dart';
import '../../services/mock_iphone_service.dart';
import '../kit.dart';
import '../../l10n/lang_scope.dart';
import '../../l10n/strings.dart';

class GeneralPane extends StatelessWidget {
  const GeneralPane({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final t = context.tr;
    final mock = app.iphone is MockIPhoneService
        ? app.iphone as MockIPhoneService
        : null;
    return Pane(
      title: t.general,
      children: [
        Group(
          children: [
            Item(
              label: t.appearance,
              trailing: Seg<ThemeMode>(
                options: {
                  ThemeMode.system: t.system,
                  ThemeMode.light: t.light,
                  ThemeMode.dark: t.dark,
                },
                value: app.themeMode,
                onChanged: app.setThemeMode,
              ),
            ),
            Item(
              label: t.language,
              trailing: Seg<AppLang?>(
                options: {
                  null: t.system,
                  AppLang.en: t.english,
                  AppLang.fr: t.french,
                },
                value: app.languageOverride,
                onChanged: app.setLanguage,
              ),
            ),
          ],
        ),
        if (mock != null) ...[
          Sec(t.simulatedDevice),
          Group(
            children: [
              Item(
                label: t.scenario,
                hint: t.mockOn,
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
        Sec(t.privacy),
        Group(
          children: [
            Item(
              leading: const Glyph(Icons.lock_outline),
              label: t.localOnly(HostPlatform.computer),
            ),
            CapItem(t.privacyDetail(HostPlatform.computer)),
          ],
        ),
        Sec(t.about),
        Group(
          children: [
            Item(label: 'iPanicX', value: t.version),
            Item(
              label: t.knowledgeBase,
              value:
                  'v${app.knowledgeBase.version ?? '?'} · ${t.signatures(app.knowledgeBase.rules.length)}',
            ),
            CapItem(t.kbDisclaimer),
            Item(
              label: t.deviceBackend,
              value: app.iphone.backendDescription,
              wrapValue: true,
            ),
          ],
        ),
      ],
    );
  }
}
