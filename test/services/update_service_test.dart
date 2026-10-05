import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/services/update_service.dart';

/// Serves a fake GitHub: the release JSON, SHA256SUMS.txt and packages.
class FakeTransport implements UpdateTransport {
  FakeTransport({this.latest, this.files = const {}, this.fail = false});

  String? latest;
  Map<String, List<int>> files;
  bool fail;
  final requested = <String>[];

  @override
  Future<String> getText(Uri url) async {
    requested.add('$url');
    if (fail) throw const SocketException('offline');
    if (url.path.endsWith('/releases/latest')) return latest ?? '';
    final f = files[url.pathSegments.last];
    if (f == null) throw HttpException('404', uri: url);
    return utf8.decode(f);
  }

  @override
  Future<void> download(
    Uri url,
    File to, {
    void Function(int received, int? total)? onProgress,
  }) async {
    requested.add('$url');
    if (fail) throw const SocketException('offline');
    final f = files[url.pathSegments.last]!;
    await to.writeAsBytes(f);
    onProgress?.call(f.length, f.length);
  }
}

String releaseJson(
  String tag, {
  bool prerelease = false,
  List<String> assets = const [],
  String repo = 'brunopaiva15/iPanicX',
}) => jsonEncode({
  'tag_name': tag,
  'draft': false,
  'prerelease': prerelease,
  'html_url': 'https://github.com/$repo/releases/tag/$tag',
  'body': '### What\'s new\n\n- **Faster**\n\n### Download\n\nzip',
  'assets': [
    for (final a in assets)
      {
        'name': a,
        'size': 4,
        'browser_download_url':
            'https://github.com/$repo/releases/download/$tag/$a',
      },
  ],
});

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ipanicx_upd_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('versions', () {
    test('parse', () {
      expect(UpdateService.parseVersion('v0.1.10'), [0, 1, 10]);
      expect(UpdateService.parseVersion('0.2.0+7'), [0, 2, 0]);
      expect(UpdateService.parseVersion('1.0'), [1, 0, 0]);
      expect(UpdateService.parseVersion('latest'), isNull);
    });

    test('compare', () {
      expect(UpdateService.isNewer('v0.1.10', '0.1.9'), isTrue);
      expect(UpdateService.isNewer('v0.2.0', '0.1.12'), isTrue);
      expect(UpdateService.isNewer('v0.1.2', '0.1.2'), isFalse);
      expect(UpdateService.isNewer('v0.1.1', '0.1.2'), isFalse);
      expect(UpdateService.isNewer('nightly', '0.1.2'), isFalse);
    });
  });

  test('release JSON: drafts and pre-releases ignored', () {
    final r = UpdateService.parseRelease(
      jsonDecode(releaseJson('v0.1.3', assets: ['SHA256SUMS.txt'])),
    )!;
    expect(r.version, '0.1.3');
    expect(r.asset('SHA256SUMS.txt'), isNotNull);
    expect(r.notes, contains('Faster'));
    expect(
      UpdateService.parseRelease(
        jsonDecode(releaseJson('v0.2.0', prerelease: true)),
      ),
      isNull,
    );
    expect(UpdateService.parseRelease('nope'), isNull);
  });

  test('package names match the release workflow', () {
    expect(
      UpdateService.packageName('0.1.3', UpdateOs.windows),
      'iPanicX-0.1.3-windows-x64.zip',
    );
    expect(
      UpdateService.packageName('0.1.3', UpdateOs.macos),
      'iPanicX-0.1.3-macos.zip',
    );
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    expect(workflow, contains(r'iPanicX-$version-windows-x64.zip'));
    expect(workflow, contains(r'iPanicX-$version-macos.zip'));
    expect(workflow, contains('SHA256SUMS.txt'));
  });

  test('SHA256SUMS.txt parsing', () {
    final h = 'a' * 64;
    expect(
      UpdateService.parseSums('$h  iPanicX-0.1.3-macos.zip\n$h *x.dmg\nbad'),
      {'iPanicX-0.1.3-macos.zip': h, 'x.dmg': h},
    );
  });

  test('only HTTPS release downloads of the repository are trusted', () {
    const repo = 'brunopaiva15/iPanicX';
    bool ok(String u) => UpdateService.isTrustedDownload(u, repo);
    expect(
      ok('https://github.com/brunopaiva15/iPanicX/releases/download/v1/a.zip'),
      isTrue,
    );
    expect(
      ok('http://github.com/brunopaiva15/iPanicX/releases/download/v1/a.zip'),
      isFalse,
    );
    expect(
      ok('https://evil.com/brunopaiva15/iPanicX/releases/download/a'),
      isFalse,
    );
    expect(
      ok('https://github.com/someone/iPanicX/releases/download/v1/a'),
      isFalse,
    );
  });

  test('install target from the running executable', () {
    expect(
      UpdateService.installTarget(
        r'C:\Users\me\Desktop\iPanicX\iPanicX.exe',
        UpdateOs.windows,
      ),
      r'C:\Users\me\Desktop\iPanicX',
    );
    expect(
      UpdateService.installTarget(r'C:\dev\flutter.exe', UpdateOs.windows),
      isNull,
    );
    expect(
      UpdateService.installTarget(
        '/Applications/iPanicX.app/Contents/MacOS/iPanicX',
        UpdateOs.macos,
      ),
      '/Applications/iPanicX.app',
    );
    expect(UpdateService.installTarget('/usr/bin/x', UpdateOs.macos), isNull);
  });

  group('check and download', () {
    const name = 'iPanicX-0.1.3-macos.zip';
    final package = utf8.encode('zip!');
    final good = '${sha256.convert(package)}  $name\n';

    UpdateService service(FakeTransport t) => UpdateService(
      transport: t,
      currentVersion: '0.1.2',
      os: UpdateOs.macos,
      tempRoot: tmp,
      releaseBuild: true,
    );

    test('newer release found, same version ignored', () async {
      final t = FakeTransport(latest: releaseJson('v0.1.3'));
      expect((await service(t).checkLatest())?.version, '0.1.3');
      t.latest = releaseJson('v0.1.2');
      expect(await service(t).checkLatest(), isNull);
      expect(
        t.requested.first,
        'https://api.github.com/repos/brunopaiva15/iPanicX/releases/latest',
      );
    });

    test('offline or garbage → network error', () async {
      expect(
        service(FakeTransport(fail: true)).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.kind,
            'kind',
            UpdateErrorKind.network,
          ),
        ),
      );
      expect(
        service(FakeTransport(latest: '<html>')).checkLatest(),
        throwsA(isA<UpdateException>()),
      );
    });

    test('download verified against SHA256SUMS.txt', () async {
      final t = FakeTransport(
        latest: releaseJson('v0.1.3', assets: [name, 'SHA256SUMS.txt']),
        files: {name: package, 'SHA256SUMS.txt': utf8.encode(good)},
      );
      final s = service(t);
      final r = (await s.checkLatest())!;
      final progress = <double>[];
      final f = await s.download(r, onProgress: progress.add);
      expect(await f.readAsBytes(), package);
      expect(progress.last, 1);
    });

    test('checksum mismatch → nothing kept', () async {
      final t = FakeTransport(
        latest: releaseJson('v0.1.3', assets: [name, 'SHA256SUMS.txt']),
        files: {
          name: package,
          'SHA256SUMS.txt': utf8.encode('${'0' * 64}  $name\n'),
        },
      );
      final s = service(t);
      final r = (await s.checkLatest())!;
      await expectLater(
        s.download(r),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.kind,
            'kind',
            UpdateErrorKind.checksum,
          ),
        ),
      );
      expect(File('${tmp.path}/iPanicX-update/$name').existsSync(), isFalse);
    });

    test('package from another repository is refused', () async {
      final t = FakeTransport(
        latest: releaseJson(
          'v0.1.3',
          assets: [name, 'SHA256SUMS.txt'],
          repo: 'someone/else',
        ),
      );
      final s = service(t);
      final r = (await s.checkLatest())!;
      expect(s.packageFor(r), isNull);
      await expectLater(
        s.download(r),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.kind,
            'kind',
            UpdateErrorKind.noPackage,
          ),
        ),
      );
    });
  });

  group('install', () {
    test('blockers', () {
      expect(
        UpdateService(os: null, detectOs: false).installBlocker,
        InstallBlocker.unsupported,
      );
      expect(
        UpdateService(os: UpdateOs.macos, releaseBuild: false).installBlocker,
        InstallBlocker.debugBuild,
      );
      expect(
        UpdateService(
          os: UpdateOs.macos,
          releaseBuild: true,
          executable:
              '/private/var/folders/x/AppTranslocation/1/d/iPanicX.app/Contents/MacOS/iPanicX',
        ).installBlocker,
        InstallBlocker.translocated,
      );
      expect(
        UpdateService(
          os: UpdateOs.macos,
          releaseBuild: true,
          executable: '/nonexistent/dir/iPanicX.app/Contents/MacOS/iPanicX',
        ).installBlocker,
        InstallBlocker.notWritable,
      );
      final app = Directory('${tmp.path}/iPanicX.app/Contents/MacOS')
        ..createSync(recursive: true);
      expect(
        UpdateService(
          os: UpdateOs.macos,
          releaseBuild: true,
          executable: '${app.path}/iPanicX',
        ).installBlocker,
        isNull,
      );
    });

    test('Windows: PowerShell script started detached, outside the app '
        'folder', () async {
      final dir = Directory("${tmp.path}/O'Brien/iPanicX")
        ..createSync(recursive: true);
      final calls = <(String, List<String>, String?)>[];
      final s = UpdateService(
        os: UpdateOs.windows,
        releaseBuild: true,
        executable: '${dir.path}/iPanicX.exe',
        currentPid: 4242,
        startDetached: (exe, args, {workingDirectory}) async =>
            calls.add((exe, args, workingDirectory)),
      );
      final pkg = File('${tmp.path}/iPanicX-update/p.zip')
        ..createSync(recursive: true);
      await s.install(pkg);
      final (exe, args, cwd) = calls.single;
      expect(exe, 'powershell.exe');
      expect(args, containsAll(['-NoProfile', '-File']));
      expect(cwd, pkg.parent.path);
      final script = File(args.last).readAsStringSync();
      expect(script, contains('Wait-Process -Id 4242'));
      // Single quotes doubled inside PowerShell literals.
      expect(script, contains("O''Brien"));
      expect(
        script,
        contains("Start-Process -FilePath (Join-Path \$dest 'iPanicX.exe')"),
      );
    });
  });

  test('macOS script swaps the bundle and relaunches (run with stub '
      'ditto/open)', () async {
    // Fake app and a "new version" zip containing iPanicX.app.
    final apps = Directory('${tmp.path}/Applications')..createSync();
    final app = '${apps.path}/iPanicX.app';
    Directory('$app/Contents/MacOS').createSync(recursive: true);
    File('$app/Contents/MacOS/iPanicX')
      ..writeAsStringSync('old')
      ..createSync();
    final build = Directory('${tmp.path}/build/iPanicX.app/Contents/MacOS')
      ..createSync(recursive: true);
    File('${build.path}/iPanicX').writeAsStringSync('new');
    await Process.run('chmod', ['+x', '${build.path}/iPanicX']);
    final zip = '${tmp.path}/new.zip';
    final z = await Process.run('zip', [
      '-qr',
      zip,
      'iPanicX.app',
    ], workingDirectory: '${tmp.path}/build');
    expect(z.exitCode, 0, reason: '${z.stderr}');

    // Stubs for the macOS tools.
    final bin = Directory('${tmp.path}/bin')..createSync();
    void stub(String name, String body) {
      final f = File('${bin.path}/$name')
        ..writeAsStringSync('#!/bin/bash\n$body\n');
      Process.runSync('chmod', ['+x', f.path]);
    }

    stub('ditto', r'unzip -q "$3" -d "$4"');
    stub('xattr', 'exit 0');
    stub('open', r'echo "$1" > "$OPENED"');

    final log = '${tmp.path}/install.log';
    final script = File('${tmp.path}/install.sh')
      ..writeAsStringSync(
        UpdateService.macScript(pid: 999999, zip: zip, app: app, log: log),
      );
    final opened = '${tmp.path}/opened';
    final r = await Process.run(
      '/bin/bash',
      [script.path],
      environment: {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'OPENED': opened,
      },
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(File(log).readAsStringSync(), contains('updated'));
    expect(File('$app/Contents/MacOS/iPanicX').readAsStringSync(), 'new');
    expect(Directory('$app.update-old').existsSync(), isFalse);
    expect(Directory('$app.update-new').existsSync(), isFalse);
    expect(File(opened).readAsStringSync().trim(), app);
  }, skip: Platform.isWindows ? 'bash script' : false);

  test(
    'macOS script keeps the current app if the package is invalid',
    () async {
      final app = '${tmp.path}/iPanicX.app';
      Directory('$app/Contents/MacOS').createSync(recursive: true);
      File('$app/Contents/MacOS/iPanicX').writeAsStringSync('old');
      final bin = Directory('${tmp.path}/bin')..createSync();
      for (final n in ['ditto', 'xattr', 'open']) {
        final f = File('${bin.path}/$n')
          ..writeAsStringSync(
            n == 'ditto' ? '#!/bin/bash\nexit 1\n' : '#!/bin/bash\nexit 0\n',
          );
        Process.runSync('chmod', ['+x', f.path]);
      }
      final log = '${tmp.path}/install.log';
      final script = File('${tmp.path}/install.sh')
        ..writeAsStringSync(
          UpdateService.macScript(
            pid: 999999,
            zip: '${tmp.path}/missing.zip',
            app: app,
            log: log,
          ),
        );
      await Process.run(
        '/bin/bash',
        [script.path],
        environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
      );
      expect(File(log).readAsStringSync(), contains('failed: invalid package'));
      expect(File('$app/Contents/MacOS/iPanicX').readAsStringSync(), 'old');
    },
    skip: Platform.isWindows ? 'bash script' : false,
  );
}
