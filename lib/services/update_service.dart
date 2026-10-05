import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../app/app_version.dart';

/// GitHub repository the releases come from.
const updateRepo = 'brunopaiva15/iPanicX';

/// Platforms that receive self-installing updates.
enum UpdateOs { windows, macos }

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, this.size});
  final String name;
  final String url;
  final int? size;
}

/// A published GitHub release.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.tag,
    required this.pageUrl,
    this.notes = '',
    this.assets = const [],
  });

  /// `0.1.3` (tag without the leading `v`).
  final String version;
  final String tag;
  final String pageUrl;

  /// Release notes (Markdown).
  final String notes;
  final List<ReleaseAsset> assets;

  ReleaseAsset? asset(String name) {
    for (final a in assets) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// Why an update cannot be installed in place (the release page is opened
/// instead).
enum InstallBlocker {
  /// Linux, or an unknown OS.
  unsupported,

  /// `flutter run`: never replace a development build.
  debugBuild,

  /// macOS runs the app from a read-only random path (App Translocation)
  /// until it is moved out of Downloads.
  translocated,

  /// No write access to the install folder.
  notWritable,
}

class UpdateException implements Exception {
  const UpdateException(this.kind, [this.detail]);

  final UpdateErrorKind kind;
  final String? detail;

  @override
  String toString() => 'UpdateException(${kind.name}: $detail)';
}

enum UpdateErrorKind { network, noPackage, checksum, install }

/// HTTP access, replaceable in tests.
abstract class UpdateTransport {
  Future<String> getText(Uri url);

  /// Writes [url] to [to]; reports bytes received and total (if known).
  Future<void> download(
    Uri url,
    File to, {
    void Function(int received, int? total)? onProgress,
  });
}

/// dart:io implementation. Sends only what any browser would (no
/// identifier): a User-Agent with the app version, which GitHub requires.
class HttpUpdateTransport implements UpdateTransport {
  HttpUpdateTransport({String userAgent = 'iPanicX/$appVersion'})
    : _userAgent = userAgent;

  final String _userAgent;

  HttpClient _client() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 15)
    ..userAgent = _userAgent;

  Future<HttpClientResponse> _get(HttpClient client, Uri url) async {
    final req = await client.getUrl(url);
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    return res;
  }

  @override
  Future<String> getText(Uri url) async {
    final client = _client();
    try {
      final res = await _get(client, url);
      return await res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> download(
    Uri url,
    File to, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final client = _client();
    IOSink? sink;
    try {
      final res = await _get(client, url);
      final total = res.contentLength > 0 ? res.contentLength : null;
      sink = to.openWrite();
      var received = 0;
      await for (final chunk in res.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }
}

/// Starts a detached process (replaceable in tests).
typedef DetachedStarter =
    Future<void> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

Future<void> _startDetached(
  String exe,
  List<String> args, {
  String? workingDirectory,
}) async {
  await Process.start(
    exe,
    args,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.detached,
  );
}

/// Checks GitHub for a newer release, downloads its package for this OS,
/// verifies it against the release's `SHA256SUMS.txt` and replaces the
/// installed app with a small script that runs once iPanicX has quit.
///
/// The only network requests: the GitHub Releases API (latest release),
/// then, if the user installs, the package and its checksum file.
class UpdateService {
  UpdateService({
    UpdateTransport? transport,
    this.currentVersion = appVersion,
    this.repo = updateRepo,
    UpdateOs? os,
    bool detectOs = true,
    String? executable,
    Directory? tempRoot,
    DetachedStarter? startDetached,
    bool? releaseBuild,
    int? currentPid,
  }) : transport = transport ?? HttpUpdateTransport(),
       os = os ?? (detectOs ? _hostOs() : null),
       _executable = executable ?? Platform.resolvedExecutable,
       _tempRoot = tempRoot ?? Directory.systemTemp,
       _start = startDetached ?? _startDetached,
       _release = releaseBuild ?? const bool.fromEnvironment('dart.vm.product'),
       _pid = currentPid ?? pid;

  final UpdateTransport transport;
  final String currentVersion;
  final String repo;

  /// Null: no self-update on this platform.
  final UpdateOs? os;
  final String _executable;
  final Directory _tempRoot;
  final DetachedStarter _start;
  final bool _release;
  final int _pid;

  static UpdateOs? _hostOs() => Platform.isWindows
      ? UpdateOs.windows
      : Platform.isMacOS
      ? UpdateOs.macos
      : null;

  Uri get latestUrl =>
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  Uri get releasesPage => Uri.parse('https://github.com/$repo/releases');

  /// The latest release if it is newer than this build, else null.
  Future<ReleaseInfo?> checkLatest() async {
    String body;
    try {
      body = await transport.getText(latestUrl);
    } catch (e) {
      throw UpdateException(UpdateErrorKind.network, '$e');
    }
    final release = parseRelease(_tryJson(body));
    if (release == null) {
      throw const UpdateException(
        UpdateErrorKind.network,
        'Unexpected answer from GitHub',
      );
    }
    return isNewer(release.version, currentVersion) ? release : null;
  }

  /// Package of [release] for this OS, or null.
  ReleaseAsset? packageFor(ReleaseInfo release) {
    final o = os;
    if (o == null) return null;
    final a = release.asset(packageName(release.version, o));
    return a != null && isTrustedDownload(a.url, repo) ? a : null;
  }

  /// Why [install] would not work here, or null when it can.
  InstallBlocker? get installBlocker {
    final o = os;
    if (o == null) return InstallBlocker.unsupported;
    if (!_release) return InstallBlocker.debugBuild;
    final target = installTarget(_executable, o);
    if (target == null) return InstallBlocker.unsupported;
    if (o == UpdateOs.macos && target.contains('/AppTranslocation/')) {
      return InstallBlocker.translocated;
    }
    // The script swaps folders next to the app: the parent must be writable.
    if (!_canWrite(Directory(target).parent)) {
      return InstallBlocker.notWritable;
    }
    return null;
  }

  /// Downloads and verifies the package of [release]. Returns the file.
  Future<File> download(
    ReleaseInfo release, {
    void Function(double fraction)? onProgress,
  }) async {
    final package = packageFor(release);
    final sums = release.asset('SHA256SUMS.txt');
    if (package == null || sums == null || !isTrustedDownload(sums.url, repo)) {
      throw const UpdateException(UpdateErrorKind.noPackage);
    }
    final dir = Directory('${_tempRoot.path}/iPanicX-update');
    final file = File('${dir.path}/${package.name}');
    Map<String, String> expected;
    try {
      await dir.create(recursive: true);
      expected = parseSums(await transport.getText(Uri.parse(sums.url)));
      await transport.download(
        Uri.parse(package.url),
        file,
        onProgress: (got, total) {
          final t = total ?? package.size;
          if (t != null && t > 0) onProgress?.call((got / t).clamp(0, 1));
        },
      );
    } catch (e) {
      throw UpdateException(UpdateErrorKind.network, '$e');
    }
    final want = expected[package.name];
    final got = await sha256OfFile(file);
    if (want == null || want.toLowerCase() != got) {
      await _delete(file);
      throw UpdateException(
        UpdateErrorKind.checksum,
        'expected ${want ?? '(missing)'}, got $got',
      );
    }
    return file;
  }

  /// Starts the script that replaces the app once this process has quit,
  /// then relaunches it. The caller must quit right after.
  Future<void> install(File package) async {
    final o = os;
    final target = o == null ? null : installTarget(_executable, o);
    if (o == null || target == null || installBlocker != null) {
      throw UpdateException(
        UpdateErrorKind.install,
        installBlocker?.name ?? 'unsupported',
      );
    }
    final dir = package.parent.path;
    final log = '$dir/install.log';
    try {
      if (o == UpdateOs.windows) {
        final script = File('$dir/install.ps1');
        await script.writeAsString(
          windowsScript(
            pid: _pid,
            zip: package.path,
            installDir: target,
            log: log,
          ),
        );
        await _start('powershell.exe', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path,
        ], workingDirectory: dir);
      } else {
        final script = File('$dir/install.sh');
        await script.writeAsString(
          macScript(pid: _pid, zip: package.path, app: target, log: log),
        );
        await _start('/bin/bash', [script.path], workingDirectory: dir);
      }
    } catch (e) {
      throw UpdateException(UpdateErrorKind.install, '$e');
    }
  }

  /// Opens [url] in the default browser.
  Future<void> openInBrowser(String url) async {
    try {
      if (os == UpdateOs.windows) {
        await _start('explorer.exe', [url]);
      } else if (os == UpdateOs.macos) {
        await _start('/usr/bin/open', [url]);
      } else {
        await _start('xdg-open', [url]);
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------ helpers

  static Object? _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  static bool _canWrite(Directory dir) {
    try {
      final probe = File('${dir.path}/.ipanicx-write-test-$pid');
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _delete(File f) async {
    try {
      await f.delete();
    } catch (_) {}
  }

  static Future<String> sha256OfFile(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  /// `v0.1.10` / `0.1.10+5` → `[0, 1, 10]`; null if not a version.
  static List<int>? parseVersion(String v) {
    final core = v
        .trim()
        .replaceFirst(RegExp('^[vV]'), '')
        .split(RegExp(r'[+\-]'))[0];
    final parts = core.split('.');
    if (parts.isEmpty || parts.length > 4) return null;
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      out.add(n);
    }
    while (out.length < 3) {
      out.add(0);
    }
    return out;
  }

  static bool isNewer(String candidate, String current) {
    final a = parseVersion(candidate), b = parseVersion(current);
    if (a == null || b == null) return false;
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// GitHub `releases/latest` JSON → [ReleaseInfo]. Drafts and
  /// pre-releases are ignored.
  static ReleaseInfo? parseRelease(Object? json) {
    if (json is! Map) return null;
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = json['tag_name'];
    if (tag is! String || parseVersion(tag) == null) return null;
    final assets = <ReleaseAsset>[];
    final raw = json['assets'];
    if (raw is List) {
      for (final a in raw) {
        if (a is! Map) continue;
        final name = a['name'], url = a['browser_download_url'];
        if (name is String && url is String) {
          assets.add(
            ReleaseAsset(
              name: name,
              url: url,
              size: a['size'] is int ? a['size'] as int : null,
            ),
          );
        }
      }
    }
    return ReleaseInfo(
      version: tag.replaceFirst(RegExp('^[vV]'), ''),
      tag: tag,
      pageUrl: json['html_url'] is String ? json['html_url'] as String : '',
      notes: json['body'] is String ? json['body'] as String : '',
      assets: assets,
    );
  }

  /// Name of the release package, as built by `.github/workflows/release.yml`.
  static String packageName(String version, UpdateOs os) => switch (os) {
    UpdateOs.windows => 'iPanicX-$version-windows-x64.zip',
    UpdateOs.macos => 'iPanicX-$version-macos.zip',
  };

  /// `SHA256SUMS.txt` (`sha256sum` output) → file name → hash.
  static Map<String, String> parseSums(String text) {
    final out = <String, String>{};
    for (final line in const LineSplitter().convert(text)) {
      final m = RegExp(
        r'^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$',
      ).firstMatch(line.trim());
      if (m != null) out[m.group(2)!] = m.group(1)!.toLowerCase();
    }
    return out;
  }

  /// Only HTTPS release downloads of [repo] on github.com.
  static bool isTrustedDownload(String url, String repo) {
    final u = Uri.tryParse(url);
    return u != null &&
        u.scheme == 'https' &&
        u.host == 'github.com' &&
        u.path.toLowerCase().startsWith(
          '/${repo.toLowerCase()}/releases/download/',
        );
  }

  /// Folder (Windows) or `.app` bundle (macOS) to replace, from the running
  /// executable. Null when it does not look like an installed iPanicX.
  static String? installTarget(String executable, UpdateOs os) {
    final exe = executable.replaceAll('\\', '/');
    switch (os) {
      case UpdateOs.windows:
        final i = exe.lastIndexOf('/');
        if (i <= 0 || exe.substring(i + 1).toLowerCase() != 'ipanicx.exe') {
          return null;
        }
        return executable.substring(0, i);
      case UpdateOs.macos:
        final i = exe.indexOf('.app/Contents/MacOS/');
        return i < 0 ? null : exe.substring(0, i + 4);
    }
  }

  static String _ps(String s) => "'${s.replaceAll("'", "''")}'";
  static String _sh(String s) => "'${s.replaceAll("'", r"'\''")}'";

  /// PowerShell: wait for iPanicX to quit, unzip next to the install folder,
  /// swap the folders (rolled back on failure), relaunch.
  static String windowsScript({
    required int pid,
    required String zip,
    required String installDir,
    required String log,
  }) {
    final dest = installDir.replaceAll('/', '\\');
    return '''
\$ErrorActionPreference = 'Stop'
\$log = ${_ps(log)}
\$dest = ${_ps(dest)}
\$stage = \$dest + '.update-new'
\$backup = \$dest + '.update-old'
function Log(\$m) { Add-Content -LiteralPath \$log -Value ((Get-Date -Format s) + ' ' + \$m) }
function Retry(\$block) {
  for (\$i = 0; \$i -lt 30; \$i++) {
    try { & \$block; return } catch { Start-Sleep -Seconds 1 }
  }
  & \$block
}
try {
  Log 'waiting for iPanicX to quit'
  try { Wait-Process -Id $pid -Timeout 60 -ErrorAction Stop } catch {}
  if (Test-Path -LiteralPath \$stage) { Remove-Item -LiteralPath \$stage -Recurse -Force }
  Expand-Archive -LiteralPath ${_ps(zip)} -DestinationPath \$stage -Force
  \$src = \$stage
  if (Test-Path -LiteralPath (Join-Path \$stage 'iPanicX\\iPanicX.exe')) { \$src = Join-Path \$stage 'iPanicX' }
  if (-not (Test-Path -LiteralPath (Join-Path \$src 'iPanicX.exe'))) { throw 'iPanicX.exe not found in the package' }
  if (Test-Path -LiteralPath \$backup) { Remove-Item -LiteralPath \$backup -Recurse -Force }
  Retry { Move-Item -LiteralPath \$dest -Destination \$backup }
  try {
    Move-Item -LiteralPath \$src -Destination \$dest
  } catch {
    Move-Item -LiteralPath \$backup -Destination \$dest
    throw
  }
  Remove-Item -LiteralPath \$backup -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$stage -Recurse -Force -ErrorAction SilentlyContinue
  Log 'updated'
} catch {
  Log ('failed: ' + \$_)
}
Start-Process -FilePath (Join-Path \$dest 'iPanicX.exe')
''';
  }

  /// bash: wait for iPanicX to quit, unzip next to the bundle, swap the
  /// bundles (rolled back on failure), relaunch.
  static String macScript({
    required int pid,
    required String zip,
    required String app,
    required String log,
  }) {
    return '''
#!/bin/bash
LOG=${_sh(log)}
APP=${_sh(app)}
ZIP=${_sh(zip)}
STAGE="\$APP.update-new"
BACKUP="\$APP.update-old"
log() { echo "\$(date '+%Y-%m-%dT%H:%M:%S') \$*" >> "\$LOG"; }
log 'waiting for iPanicX to quit'
for _ in \$(seq 1 120); do kill -0 $pid 2>/dev/null || break; sleep 0.5; done
rm -rf "\$STAGE" && mkdir -p "\$STAGE"
NEW=""
if ditto -x -k "\$ZIP" "\$STAGE"; then
  NEW=\$(find "\$STAGE" -maxdepth 1 -name '*.app' -print -quit)
fi
if [ -n "\$NEW" ] && [ -x "\$NEW/Contents/MacOS/iPanicX" ]; then
  xattr -dr com.apple.quarantine "\$NEW" 2>/dev/null
  rm -rf "\$BACKUP"
  if mv "\$APP" "\$BACKUP"; then
    if mv "\$NEW" "\$APP"; then
      rm -rf "\$BACKUP"
      log 'updated'
    else
      mv "\$BACKUP" "\$APP"
      log 'failed: could not move the new app into place'
    fi
  else
    log 'failed: could not move the current app'
  fi
else
  log 'failed: invalid package'
fi
rm -rf "\$STAGE"
open "\$APP"
''';
  }
}
