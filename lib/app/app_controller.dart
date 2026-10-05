import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import '../diagnostics/knowledge_base.dart';
import '../models/device_status.dart';
import '../models/scan_result.dart';
import '../services/diagnostic_service.dart';
import '../services/iphone_service.dart';
import '../services/platform_bridge.dart';

enum ScanPhase { idle, copying, analyzing, done, failed }

/// App-wide state: device status, last scan and its errors.
class AppController extends ChangeNotifier {
  AppController({
    required this.iphone,
    required this.knowledgeBase,
    PlatformBridge? bridge,
    bool useIsolate = true,
  }) : bridge = bridge ?? PlatformBridge.forHost(),
       diagnostics = DiagnosticService(
         iphone: iphone,
         knowledgeBase: knowledgeBase,
         useIsolate: useIsolate,
       );

  final IPhoneService iphone;
  final KnowledgeBase knowledgeBase;
  final DiagnosticService diagnostics;
  final PlatformBridge bridge;

  /// Dark by default (the black Codenotch-style surfaces); switchable from
  /// the sidebar.
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
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

  Future<void> start() async {
    _sub = iphone.status.listen(_onStatus);
    await iphone.start();
  }

  void _onStatus(DeviceStatus s) {
    _status = s;
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
    notifyListeners();
    try {
      final result = await diagnostics.scan(
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
        'Something went wrong while reading the crash reports.',
        technicalDetails: e.toString(),
      );
      _phase = ScanPhase.failed;
    }
    notifyListeners();
  }

  Future<void> retry() => iphone.refresh();

  Future<void> requestPairing() => iphone.requestPairing();

  @override
  void dispose() {
    _sub?.cancel();
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
