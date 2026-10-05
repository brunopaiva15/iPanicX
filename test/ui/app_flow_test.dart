import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/app/app.dart';
import 'package:ipanicx/app/app_controller.dart';
import 'package:ipanicx/app/host_platform.dart';
import 'package:ipanicx/l10n/strings.dart';
import 'package:ipanicx/services/history_store.dart';
import 'package:ipanicx/ui/panes/shared.dart';
import 'package:ipanicx/services/mock_iphone_service.dart';

import '../helpers.dart';

/// Bounded alternative to pumpAndSettle: some screens show indeterminate
/// progress indicators that never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ipanicx_ui_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(AppController, MockIPhoneService)> pumpApp(
    WidgetTester tester, {
    MockScenario scenario = MockScenario.connected,
    String locale = 'en_US',
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final mock = MockIPhoneService(
      scenario: scenario,
      sampleLoader: sampleLoader,
      workRoot: tmp,
      latency: Duration.zero,
    );
    final controller = AppController(
      iphone: mock,
      knowledgeBase: loadKnowledgeBase(),
      useIsolate: false,
      systemLocale: locale,
      history: HistoryStore(root: Directory('${tmp.path}/history')),
    );
    await tester.pumpWidget(IPanicXApp(controller: controller));
    await tester.runAsync(controller.start);
    await settle(tester);
    return (controller, mock);
  }

  testWidgets('connected iPhone → scan → analyze → diagnosis', (tester) async {
    final (controller, _) = await pumpApp(tester);

    expect(find.text('iPhone 14 Pro'), findsWidgets);
    expect(find.text('Connected via USB'), findsOneWidget);
    expect(find.text('26.0.1'), findsOneWidget);
    expect(find.text('iPhone15,2'), findsOneWidget);
    // UDID is masked.
    expect(find.text('00008120-001A2B3C4D5E6F7A'), findsNothing);

    // The scan does real file I/O: run it outside the fake-async zone.
    expect(find.text('Scan Diagnostics'), findsOneWidget);
    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);

    expect(controller.scanError, isNull);
    expect(find.text('Kernel Panics'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('Device Health'), findsOneWidget);
    expect(find.text('Hardware issue likely'), findsOneWidget);
    expect(find.textContaining('SMC Sensor Failure  (12×)'), findsOneWidget);

    await tester.tap(find.text('Analyze'));
    await settle(tester);

    expect(find.text('SMC Sensor Failure'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('High confidence'), findsOneWidget);
    expect(find.text('Charging Port Flex'), findsOneWidget);
    expect(find.text('Power Button Flex'), findsOneWidget);
    expect(
      find.textContaining('confirmed by hardware inspection'),
      findsOneWidget,
    );
    expect(find.textContaining('0x140000'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('View Raw Panic'),
      300,
      // The pane's list (SelectableTexts have scrollables of their own).
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('View Raw Panic'));
    await settle(tester);
    expect(find.text('Copy All'), findsOneWidget);
  });

  testWidgets('no iPhone connected', (tester) async {
    await pumpApp(tester, scenario: MockScenario.noDevice);
    expect(find.text('No iPhone connected'), findsOneWidget);
    expect(find.textContaining('Connect an iPhone using USB'), findsOneWidget);
    expect(find.text('iPhone plugged in but not detected?'), findsOneWidget);
  });

  testWidgets('iPhone on USB but not recognized', (tester) async {
    await pumpApp(tester, scenario: MockScenario.notRecognized);
    expect(find.text('iPhone not recognized'), findsOneWidget);
    expect(find.textContaining('Apple USB driver'), findsOneWidget);
    // OS query output stays in the technical section.
    expect(find.textContaining('PID_12A8'), findsNothing);
  });

  testWidgets('driver error on Windows: steps and Device Manager', (
    tester,
  ) async {
    final saved = HostPlatform.isWindows;
    HostPlatform.isWindows = true;
    addTearDown(() => HostPlatform.isWindows = saved);

    await pumpApp(tester, scenario: MockScenario.notRecognized);
    expect(find.text('Open Device Manager'), findsOneWidget);
    expect(find.textContaining('Restart the PC'), findsOneWidget);
    expect(find.textContaining('Optional updates'), findsOneWidget);
  });

  testWidgets('trust required → pairing → connected', (tester) async {
    final (_, mock) = await pumpApp(
      tester,
      scenario: MockScenario.trustRequired,
    );
    expect(find.text('Trust required'), findsOneWidget);
    // Raw lockdown error is hidden behind the technical section.
    expect(find.textContaining('(-19)'), findsNothing);

    await tester.tap(find.text('Show Trust Prompt'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await settle(tester);
    expect(mock.scenario, MockScenario.connected);
    expect(find.text('Scan Diagnostics'), findsOneWidget);
  });

  testWidgets('libimobiledevice unavailable', (tester) async {
    await pumpApp(tester, scenario: MockScenario.toolsUnavailable);
    expect(find.text('libimobiledevice unavailable'), findsOneWidget);
    expect(find.text('brew install libimobiledevice'), findsOneWidget);
  });

  testWidgets('multiple devices warning', (tester) async {
    await pumpApp(tester, scenario: MockScenario.multipleDevices);
    expect(find.textContaining('2 devices are connected'), findsOneWidget);
  });

  testWidgets('crash report failure is explained', (tester) async {
    final (controller, _) = await pumpApp(
      tester,
      scenario: MockScenario.crashReportError,
    );
    // The scan does real file I/O: run it outside the fake-async zone.
    expect(find.text('Scan Diagnostics'), findsOneWidget);
    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);
    expect(find.text('Unable to retrieve crash reports'), findsOneWidget);
    expect(find.text('Technical details'), findsOneWidget);
  });

  testWidgets('General shows the privacy statement', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('General'));
    await settle(tester);
    expect(
      find.text('All diagnostic processing is performed locally on your Mac.'),
      findsOneWidget,
    );
  });

  testWidgets('Windows wording (PC, File Explorer, MSYS2)', (tester) async {
    final saved = HostPlatform.isWindows;
    HostPlatform.isWindows = true;
    addTearDown(() => HostPlatform.isWindows = saved);

    await pumpApp(tester, scenario: MockScenario.toolsUnavailable);
    expect(find.textContaining('flutter build windows'), findsOneWidget);
    expect(find.textContaining('pacman -S'), findsOneWidget);

    await tester.tap(find.text('General'));
    await settle(tester);
    expect(
      find.text('All diagnostic processing is performed locally on your PC.'),
      findsOneWidget,
    );
  });

  testWidgets('Apple Mobile Device Service missing (Windows)', (tester) async {
    final saved = HostPlatform.isWindows;
    HostPlatform.isWindows = true;
    addTearDown(() => HostPlatform.isWindows = saved);

    await pumpApp(tester, scenario: MockScenario.usbServiceDown);
    expect(
      find.text('Apple Mobile Device Service not running'),
      findsOneWidget,
    );
    expect(find.text('Open Microsoft Store'), findsOneWidget);
    expect(find.textContaining('services.msc'), findsOneWidget);
    expect(find.textContaining('27015'), findsNothing);
  });

  testWidgets('warns when Apple Devices is not installed (French)', (
    tester,
  ) async {
    final saved = HostPlatform.isWindows;
    HostPlatform.isWindows = true;
    addTearDown(() => HostPlatform.isWindows = saved);
    addTearDown(() => L10n.lang = AppLang.en);

    await pumpApp(
      tester,
      scenario: MockScenario.appleDevicesMissing,
      locale: 'fr_FR',
    );
    expect(find.text('Apple Devices n’est pas installé'), findsOneWidget);
    expect(find.text('Installer Apple Devices'), findsOneWidget);
    expect(find.textContaining('Microsoft Store'), findsOneWidget);
  });

  testWidgets('health pane: device facts, checklist, main issue', (
    tester,
  ) async {
    final (controller, _) = await pumpApp(tester);
    // Facts are read as soon as the device is connected.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await settle(tester);
    expect(controller.facts?.battery?.healthPercent, 78);

    await tester.tap(find.text('Health'));
    await settle(tester);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Health 78 % · 843 cycles'), findsOneWidget);
    expect(find.text('Scan the iPhone first'), findsWidgets);

    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);
    expect(find.text('Problem detected'), findsOneWidget);
    expect(find.text('Main issue'), findsOneWidget);
    expect(
      find.text(
        '12 kernel panics with the same sensor mask 0x140000 (iPhone15,2)',
      ),
      findsOneWidget,
    );
    expect(find.text('9 in 7 days'), findsOneWidget);
  });

  testWidgets('second scan: compared with the previous one, full report', (
    tester,
  ) async {
    final (controller, _) = await pumpApp(tester);
    await tester.runAsync(controller.scanDiagnostics);
    expect(controller.previousScan, isNull);
    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);
    expect(controller.previousScan, isNotNull);
    expect(controller.newPanicsSincePrevious, 0);

    await tester.tap(find.text('Health'));
    await settle(tester);
    expect(find.textContaining('Since the last scan'), findsOneWidget);
    expect(find.text('no new kernel panic'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Full report'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Full report'), findsOneWidget);

    // Two summaries saved locally (file I/O: outside the fake clock).
    expect(await tester.runAsync(controller.history.count), 2);
  });

  testWidgets('app crashes: pattern, by app, crash details', (tester) async {
    final (controller, _) = await pumpApp(tester, locale: 'fr_FR');
    addTearDown(() => L10n.lang = AppLang.en);
    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);

    await tester.tap(find.text('Panics'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('9 sur 7 jours'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('9 sur 7 jours'));
    await settle(tester);
    expect(find.text('Crashs d’apps'), findsWidgets);
    expect(find.text('Surtout une seule app'), findsOneWidget);
    expect(find.textContaining('Instagram : un problème'), findsOneWidget);
    expect(find.text('Par cause'), findsOneWidget);

    await tester.tap(find.text('Instagram'));
    await settle(tester);
    expect(find.text('5 crash'), findsNothing);
    expect(find.text('Erreur mémoire'), findsWidgets);
    await tester.tap(find.text('Erreur mémoire').first);
    await settle(tester);
    expect(find.textContaining('KERN_INVALID_ADDRESS'), findsOneWidget);
    expect(find.text('Instagram  IGFeedRenderer.layout()'), findsOneWidget);

    await tester.tap(find.byType(BackButtonSmall));
    await settle(tester);
    await tester.tap(find.text('30 jours'));
    await settle(tester);
    expect(find.text('Par jour'), findsOneWidget);
  });

  testWidgets('console: live log with explained events', (tester) async {
    final (controller, _) = await pumpApp(tester, locale: 'fr_FR');
    addTearDown(() => L10n.lang = AppLang.en);
    await tester.tap(find.text('Console'));
    await settle(tester);
    await tester.tap(find.text('Démarrer'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.console.lineCount, greaterThan(2));
    expect(find.text('Un capteur matériel est manquant'), findsOneWidget);

    await tester.tap(find.text('Événements seulement'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('SpringBoard'), findsNothing);

    await tester.tap(find.text('Arrêter'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.console.running, isFalse);
  });

  testWidgets('disconnect while reading a diagnosis returns to overview', (
    tester,
  ) async {
    final (controller, mock) = await pumpApp(tester);
    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);
    await tester.tap(find.text('Analyze'));
    await settle(tester);
    expect(find.text('Charging Port Flex'), findsOneWidget);

    mock.setScenario(MockScenario.noDevice);
    await settle(tester);
    expect(find.text('No iPhone connected'), findsOneWidget);
    expect(find.text('Charging Port Flex'), findsNothing);
  });

  testWidgets('appearance picker switches theme mode', (tester) async {
    final (controller, _) = await pumpApp(tester);
    expect(controller.themeMode, ThemeMode.system);
    await tester.tap(find.text('General'));
    await settle(tester);
    await tester.tap(find.text('Light'));
    await settle(tester);
    expect(controller.themeMode, ThemeMode.light);
  });

  testWidgets('French system locale → French UI and diagnosis', (tester) async {
    final (controller, _) = await pumpApp(tester, locale: 'fr_FR');
    addTearDown(() => L10n.lang = AppLang.en);
    expect(controller.language, AppLang.fr);
    expect(find.text('Vue d’ensemble'), findsWidgets);
    expect(find.text('Connecté en USB'), findsOneWidget);

    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);
    expect(find.text('État de l’appareil'), findsOneWidget);
    expect(find.text('Problème matériel probable'), findsOneWidget);
    expect(find.textContaining('Panne de capteur SMC  (12×)'), findsOneWidget);

    await tester.tap(find.text('Analyser').last);
    await settle(tester);
    expect(find.text('Panne de capteur SMC'), findsOneWidget);
    expect(find.text('Confiance élevée'), findsOneWidget);
    expect(find.text('Nappe du connecteur de charge'), findsOneWidget);
  });

  testWidgets('General › Language switches the whole app live', (tester) async {
    final (controller, _) = await pumpApp(tester);
    addTearDown(() => L10n.lang = AppLang.en);
    await tester.runAsync(controller.scanDiagnostics);
    await settle(tester);

    await tester.tap(find.text('General'));
    await settle(tester);
    await tester.tap(find.text('Français'));
    await settle(tester);
    expect(controller.language, AppLang.fr);
    expect(find.text('Général'), findsWidgets);
    expect(find.text('Langue'), findsOneWidget);

    await tester.tap(find.text('Vue d’ensemble'));
    await settle(tester);
    // The existing scan is re-worded, not re-copied.
    expect(find.text('Problème matériel probable'), findsOneWidget);

    await tester.tap(find.text('Général'));
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(find.text('Language'), findsOneWidget);
    expect(controller.scan!.panics.first.result.title, 'SMC Sensor Failure');
  });
}
