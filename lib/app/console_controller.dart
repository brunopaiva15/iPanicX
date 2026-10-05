import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/log_rules.dart';
import '../services/iphone_service.dart';

/// Live log of the connected iPhone, classified line by line.
///
/// Lines arrive much faster than the UI needs to repaint, so listeners are
/// notified at most every [_tick].
class ConsoleController extends ChangeNotifier {
  ConsoleController(this._iphone);

  final IPhoneService _iphone;

  /// Oldest lines are dropped beyond this.
  static const capacity = 5000;
  static const _tick = Duration(milliseconds: 150);

  final List<ClassifiedLine> _lines = [];
  int _events = 0;
  StreamSubscription<String>? _sub;
  Timer? _flush;
  bool _dirty = false;
  bool _paused = false;
  bool eventsOnly = false;
  Object? error;

  bool get running => _sub != null;
  bool get paused => _paused;
  int get lineCount => _lines.length;
  int get eventCount => _events;

  /// Newest first, filtered by [eventsOnly].
  List<ClassifiedLine> get visible {
    final list = eventsOnly ? _lines.where((l) => l.isEvent) : _lines;
    return list.toList().reversed.toList(growable: false);
  }

  void start() {
    if (running) return;
    error = null;
    _paused = false;
    _sub = _iphone.syslog().listen(
      _onLine,
      onError: (Object e) {
        error = e;
        stop();
      },
      onDone: stop,
    );
    _flush = Timer.periodic(_tick, (_) {
      if (_dirty) {
        _dirty = false;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _flush?.cancel();
    _flush = null;
    _paused = false;
    notifyListeners();
  }

  /// Pausing keeps the process running but stops adding lines, so the
  /// technician can read; lines received meanwhile are dropped.
  void togglePause() {
    _paused = !_paused;
    notifyListeners();
  }

  void setEventsOnly(bool value) {
    eventsOnly = value;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _events = 0;
    notifyListeners();
  }

  /// Plain text of every line, oldest first.
  String export() => _lines.map((l) => l.text).join('\n');

  void _onLine(String line) {
    if (_paused || line.trim().isEmpty) return;
    final c = LogRules.classify(line);
    _lines.add(c);
    if (c.isEvent) _events++;
    if (_lines.length > capacity) {
      final removed = _lines.removeAt(0);
      if (removed.isEvent) _events--;
    }
    _dirty = true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flush?.cancel();
    super.dispose();
  }
}
