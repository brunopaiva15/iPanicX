import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/app/update_controller.dart';
import 'package:ipanicx/services/settings_store.dart';
import 'package:ipanicx/services/update_service.dart';

import '../services/update_service_test.dart' show FakeTransport, releaseJson;

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ipanicx_updc_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  const name = 'iPanicX-0.1.3-macos.zip';
  final package = utf8.encode('zip!');

  FakeTransport github() => FakeTransport(
    latest: releaseJson('v0.1.3', assets: [name, 'SHA256SUMS.txt']),
    files: {
      name: package,
      'SHA256SUMS.txt': utf8.encode('${sha256.convert(package)}  $name\n'),
    },
  );

  UpdateService service(
    FakeTransport t, {
    bool releaseBuild = true,
    List<String>? started,
  }) {
    final app = Directory('${tmp.path}/iPanicX.app/Contents/MacOS')
      ..createSync(recursive: true);
    return UpdateService(
      transport: t,
      currentVersion: '0.1.2',
      os: UpdateOs.macos,
      tempRoot: tmp,
      releaseBuild: releaseBuild,
      executable: '${app.path}/iPanicX',
      startDetached: (exe, args, {workingDirectory}) async =>
          started?.add([exe, ...args].join(' ')),
    );
  }

  test('launch check: at most once per interval, setting respected', () async {
    final t = github();
    final now = DateTime(2026, 10, 5, 12);
    final settings = MemorySettingsStore({
      UpdateController.lastCheckKey: now
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
    });
    final c = UpdateController(
      service: service(t),
      settings: settings,
      now: () => now,
    );
    await c.checkOnLaunch();
    expect(t.requested, isEmpty, reason: 'checked 2 h ago');

    final old = UpdateController(
      service: service(t),
      settings: MemorySettingsStore({
        UpdateController.lastCheckKey: now
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      }),
      now: () => now,
    );
    await old.checkOnLaunch();
    expect(old.phase, UpdatePhase.available);
    expect(old.release?.version, '0.1.3');
    expect(old.hasUpdate, isTrue);

    final off = UpdateController(
      service: service(FakeTransport(latest: releaseJson('v0.1.3'))),
      settings: MemorySettingsStore({UpdateController.autoCheckKey: false}),
    );
    await off.checkOnLaunch();
    expect(off.autoCheck, isFalse);
    expect(off.phase, UpdatePhase.idle);
  });

  test(
    'automatic check offline stays silent; manual check reports it',
    () async {
      final c = UpdateController(service: service(FakeTransport(fail: true)));
      await c.checkOnLaunch();
      expect(c.phase, UpdatePhase.idle);
      expect(c.error, isNull);
      await c.check();
      expect(c.phase, UpdatePhase.failed);
      expect(c.error?.kind, UpdateErrorKind.network);
    },
  );

  test('up to date', () async {
    final c = UpdateController(
      service: service(FakeTransport(latest: releaseJson('v0.1.2'))),
    );
    await c.check();
    expect(c.phase, UpdatePhase.upToDate);
    expect(c.hasUpdate, isFalse);
    expect(c.lastCheck, isNotNull);
  });

  test(
    'install: download, verify, stop the tools, start the script, quit',
    () async {
      final started = <String>[];
      var stopped = false, quit = false;
      final c = UpdateController(
        service: service(github(), started: started),
        quit: () => quit = true,
      )..beforeQuit = () async => stopped = true;
      await c.check();
      await c.install();
      expect(c.phase, UpdatePhase.installing);
      expect(stopped, isTrue);
      expect(started.single, startsWith('/bin/bash '));
      expect(quit, isTrue);
    },
  );

  test('cannot install in place → opens the release page', () async {
    final started = <String>[];
    var quit = false;
    final c = UpdateController(
      service: service(github(), releaseBuild: false, started: started),
      quit: () => quit = true,
    );
    await c.check();
    expect(c.installBlocker, InstallBlocker.debugBuild);
    await c.install();
    expect(started.single, contains('/releases/tag/v0.1.3'));
    expect(quit, isFalse);
  });

  test('checksum failure keeps the app running', () async {
    final t = github()
      ..files = {
        name: package,
        'SHA256SUMS.txt': utf8.encode('${'0' * 64}  $name\n'),
      };
    var quit = false;
    final c = UpdateController(service: service(t), quit: () => quit = true);
    await c.check();
    await c.install();
    expect(c.phase, UpdatePhase.failed);
    expect(c.error?.kind, UpdateErrorKind.checksum);
    expect(c.hasUpdate, isTrue, reason: 'can retry');
    expect(quit, isFalse);
  });

  test('setting is saved', () async {
    final settings = MemorySettingsStore();
    final c = UpdateController(
      service: service(FakeTransport()),
      settings: settings,
    );
    await c.setAutoCheck(false);
    expect((await settings.read())[UpdateController.autoCheckKey], false);
  });

  test('without a service nothing happens', () async {
    final c = UpdateController();
    expect(c.supported, isFalse);
    await c.checkOnLaunch();
    await c.check();
    expect(c.phase, UpdatePhase.idle);
  });

  test('settings file round trip', () async {
    final s = SettingsStore(file: File('${tmp.path}/x/settings.json'));
    expect(await s.read(), isEmpty);
    await s.write({'a': 1});
    await s.write({'b': true});
    expect(await s.read(), {'a': 1, 'b': true});
  });
}
