import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/foundation.dart';

import '../services/settings_store.dart';
import '../services/update_service.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  failed,
}

/// Update state shown in the sidebar and in General › Updates.
///
/// On launch, checks GitHub at most once a day unless the user turned it
/// off. Installing downloads the package, verifies its SHA-256, starts the
/// replacement script and quits; the script relaunches the new version.
class UpdateController extends ChangeNotifier {
  UpdateController({
    this.service,
    SettingsStore? settings,
    DateTime Function()? now,
    Future<void> Function()? beforeQuit,
    void Function()? quit,
  }) : _settings = settings ?? MemorySettingsStore(),
       _now = now ?? DateTime.now,
       _beforeQuit = beforeQuit,
       _quit = quit ?? (() => exit(0));

  /// Null: updates disabled (tests, unsupported platform).
  final UpdateService? service;
  final SettingsStore _settings;
  final DateTime Function() _now;
  Future<void> Function()? _beforeQuit;
  final void Function() _quit;

  static const autoCheckKey = 'autoUpdateCheck';
  static const lastCheckKey = 'lastUpdateCheck';
  static const checkInterval = Duration(hours: 20);

  bool get supported => service?.os != null;

  UpdatePhase _phase = UpdatePhase.idle;
  UpdatePhase get phase => _phase;

  ReleaseInfo? _release;

  /// Newer release found by the last check.
  ReleaseInfo? get release => _release;

  double? _progress;

  /// Download progress (0–1), null when unknown.
  double? get progress => _progress;

  UpdateException? _error;
  UpdateException? get error => _error;

  bool _autoCheck = true;
  bool get autoCheck => _autoCheck;

  DateTime? _lastCheck;
  DateTime? get lastCheck => _lastCheck;

  /// Runs before quitting to install (stops the device tools).
  set beforeQuit(Future<void> Function()? f) => _beforeQuit = f;

  bool get busy =>
      _phase == UpdatePhase.checking ||
      _phase == UpdatePhase.downloading ||
      _phase == UpdatePhase.installing;

  /// An update can be installed (or opened) from the sidebar.
  bool get hasUpdate =>
      _release != null &&
      (_phase == UpdatePhase.available ||
          _phase == UpdatePhase.downloading ||
          _phase == UpdatePhase.installing ||
          _phase == UpdatePhase.failed);

  /// Why the update would open the release page instead of installing.
  InstallBlocker? get installBlocker => service?.installBlocker;

  void _set(UpdatePhase p) {
    _phase = p;
    notifyListeners();
  }

  /// Loads the setting and checks if the last check is old enough.
  Future<void> checkOnLaunch() async {
    if (!supported) return;
    final s = await _settings.read();
    _autoCheck = s[autoCheckKey] != false;
    _lastCheck = DateTime.tryParse('${s[lastCheckKey]}');
    notifyListeners();
    if (!_autoCheck) return;
    final last = _lastCheck;
    if (last != null && _now().difference(last) < checkInterval) return;
    await check(silent: true);
  }

  /// Asks GitHub for the latest release. [silent]: a failure only goes back
  /// to idle (automatic check, possibly offline).
  Future<void> check({bool silent = false}) async {
    final svc = service;
    if (svc == null || busy) return;
    _error = null;
    _set(UpdatePhase.checking);
    try {
      _release = await svc.checkLatest();
      _lastCheck = _now();
      await _settings.write({lastCheckKey: _lastCheck!.toIso8601String()});
      _set(_release == null ? UpdatePhase.upToDate : UpdatePhase.available);
    } on UpdateException catch (e) {
      _error = silent ? null : e;
      _set(silent ? UpdatePhase.idle : UpdatePhase.failed);
    }
  }

  Future<void> setAutoCheck(bool on) async {
    if (on == _autoCheck) return;
    _autoCheck = on;
    notifyListeners();
    await _settings.write({autoCheckKey: on});
  }

  /// Downloads, verifies and installs the release, then quits. Opens the
  /// release page instead when it cannot be installed in place.
  Future<void> install() async {
    final svc = service, release = _release;
    if (svc == null || release == null || busy) return;
    if (svc.installBlocker != null || svc.packageFor(release) == null) {
      await openReleasePage();
      return;
    }
    _error = null;
    _progress = null;
    _set(UpdatePhase.downloading);
    try {
      final file = await svc.download(
        release,
        onProgress: (f) {
          _progress = f;
          notifyListeners();
        },
      );
      _set(UpdatePhase.installing);
      await _beforeQuit?.call();
      await svc.install(file);
    } on UpdateException catch (e) {
      _error = e;
      _set(UpdatePhase.failed);
      return;
    }
    _quit();
  }

  Future<void> openReleasePage() async {
    final svc = service;
    if (svc == null) return;
    final url = _release?.pageUrl;
    await svc.openInBrowser(
      url == null || url.isEmpty ? svc.releasesPage.toString() : url,
    );
  }
}
