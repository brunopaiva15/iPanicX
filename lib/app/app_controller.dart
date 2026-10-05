import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import '../diagnostics/health_report.dart';
import '../diagnostics/knowledge_base.dart';
import '../l10n/strings.dart';
import '../models/device_facts.dart';
import '../models/device_status.dart';
import '../models/scan_result.dart';
import '../services/diagnostic_service.dart';
import '../services/iphone_service.dart';
import '../services/platform_bridge.dart';
import 'console_controller.dart';

enum ScanPhase { idle, copying, analyzing, done, failed }

/// App-wide state: device status, last scan and its errors.
class AppController extends ChangeNotifier {
  AppController({
    required this.iphone,
    required this.knowledgeBase,
    PlatformBridge? bridge,
    bool useIsolate = true,
    String? systemLocale,
  }) : _systemLang = AppLang.fromLocale(
         systemLocale ?? PlatformDispatcher.instance.locale.toLanguageTag(),
       ),
       bridge = bridge ?? PlatformBridge.forHost(),
       diagnostics = DiagnosticService(
         iphone: iphone,
         knowledgeBase: knowledgeBase,
         useIsolate: useIsolate,
       ) {
    L10n.lang = language;
  }

  final IPhoneService iphone;
  final KnowledgeBase knowledgeBase;
  final DiagnosticService diagnostics;
  final PlatformBridge bridge;

  /// Live log of the connected device.
  late final ConsoleController console = ConsoleController(iphone);

  /// Follows the system by default; General › Appearance overrides it.
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  /// Language of the OS; used unless General › Language overrides it.
  final AppLang _systemLang;
  AppLang? _langOverride;

  /// `null` = follow the system.
  AppLang? get languageOverride => _langOverride;
  AppLang get language => _langOverride ?? _systemLang;

  void setLanguage(AppLang? lang) {
    if (lang == _langOverride) return;
    final before = language;
    _langOverride = lang;
    L10n.lang = language;
    // Diagnoses are generated texts: regenerate them in the new language.
    if (language != before && _scan != null) {
      _scan = diagnostics.relocalize(_scan!, language);
    }
    notifyListeners();
  }

  DeviceStatus _status = const DeviceStatus.searching();
  DeviceStatus get status => _status;

  ScanPhase _phase = ScanPhase.idle;
  ScanPhase get phase => _phase;
  bool get isScanning =>
      _phase == ScanPhase.copying || _phase == ScanPhase.analyzing;

  int _copiedFiles = 0;
  int get copiedFiles => _copiedFiles;

  ScanResult? _scan;
  ScanResult? get scan => _scan;

  IPhoneServiceException? _scanError;
  IPhoneServiceException? get scanError => _scanError;

  String? _scannedUdid;
  StreamSubscription<DeviceStatus>? _sub;
  Completer<void>? _cancelScan;

  // Device facts (battery, storage…), read when a device connects and
  // after each scan.
  DeviceFacts? _facts;
  DeviceFacts? get facts => _facts;
  bool _loadingFacts = false;
  bool get loadingFacts => _loadingFacts;
  String? _factsUdid;

  Future<void> loadFacts() async {
    if (_loadingFacts || !_status.isConnected) return;
    // The lockdown connection is busy while reports are copied.
    if (isScanning) return;
    final udid = _status.udid;
    _loadingFacts = true;
    notifyListeners();
    try {
      final f = await iphone.getDeviceFacts();
      if (_status.udid == udid) _facts = f;
    } catch (_) {
      // Facts are optional; the health checks show "not available".
    } finally {
      _loadingFacts = false;
      notifyListeners();
    }
  }

  HealthReport? _health;
  Object? _healthKey;

  /// Checklist from the last scan and the device facts, in the UI language.
  HealthReport get health {
    final key = (_scan, _facts, language);
    if (_health == null || _healthKey != key) {
      _healthKey = key;
      _health = HealthReport.build(
        s: Strings(language),
        knowledgeBase: knowledgeBase,
        scan: _scan,
        facts: _facts,
      );
    }
    return _health!;
  }

  Future<void> start() async {
    _sub = iphone.status.listen(_onStatus);
    await iphone.start();
  }

  void _onStatus(DeviceStatus s) {
    _status = s;
    if (!s.isConnected) {
      _facts = null;
      _factsUdid = null;
      if (console.running) console.stop();
    } else if (s.udid != _factsUdid) {
      _factsUdid = s.udid;
      _facts = null;
      if (console.running) console.stop();
      scheduleMicrotask(loadFacts);
    }
    // A different (or no) device invalidates the previous scan.
    if (_scannedUdid != null && s.udid != _scannedUdid && !isScanning) {
      if (s.state == DeviceConnectionState.noDevice || s.udid != null) {
        _clearScan();
      }
    }
    notifyListeners();
  }

  void _clearScan() {
    _scan = null;
    _scanError = null;
    _scannedUdid = null;
    _phase = ScanPhase.idle;
  }

  Future<void> scanDiagnostics() async {
    if (isScanning || !_status.isConnected) return;
    _phase = ScanPhase.copying;
    _copiedFiles = 0;
    _scanError = null;
    _cancelScan = Completer<void>();
    notifyListeners();
    try {
      final result = await diagnostics.scan(
        cancel: _cancelScan!.future,
        onProgress: (count, _) {
          _copiedFiles = count;
          if (_phase == ScanPhase.copying) notifyListeners();
        },
        onAnalyzing: () {
          _phase = ScanPhase.analyzing;
          notifyListeners();
        },
      );
      _scan = result;
      _scannedUdid = _status.udid;
      _phase = ScanPhase.done;
    } on IPhoneServiceException catch (e) {
      _scanError = e;
      _phase = ScanPhase.failed;
    } catch (e) {
      _scanError = IPhoneServiceException(
        IPhoneErrorKind.crashReportsUnavailable,
        tr.scanFailedGeneric,
        technicalDetails: e.toString(),
      );
      _phase = ScanPhase.failed;
    }
    _cancelScan = null;
    notifyListeners();
    if (_phase == ScanPhase.done) unawaited(loadFacts());
  }

  /// Stops the copy in progress (nothing is changed on the iPhone).
  void cancelScan() {
    final c = _cancelScan;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> retry() => iphone.refresh();

  Future<void> requestPairing() => iphone.requestPairing();

  @override
  void dispose() {
    _sub?.cancel();
    console.dispose();
    iphone.dispose();
    super.dispose();
  }
}

/// Makes the [AppController] available to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
