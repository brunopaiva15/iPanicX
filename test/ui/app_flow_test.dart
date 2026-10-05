import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipanix/app/app.dart';
import 'package:ipanix/app/app_controller.dart';
import 'package:ipanix/app/host_platform.dart';
import 'package:ipanix/l10n/strings.dart';
import 'package:ipanix/services/mock_iphone_service.dart';

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
  setUp(() => tmp = Directory.systemTemp.createTempSync('ipanix_ui_'));
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
    );
    await tester.pumpWidget(IPaniXApp(controller: controller));
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
    expect(find.text('14'), findsOneWidget);
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
