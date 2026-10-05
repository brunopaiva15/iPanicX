import '../l10n/strings.dart';
import '../models/diagnostic_result.dart';
import '../models/scan_result.dart';
import 'knowledge_base.dart';

/// What links several panics together.
enum ClueKind {
  /// `Missing sensor(s): TG0B` (thermalmonitord).
  missingSensor,

  /// Same SMC sensor mask on the same model.
  sensorMask,

  /// Same service missing its watchdog check-ins.
  watchdogService,

  /// Same diagnosis / panic signature.
  signature;

  bool get isHardwareClue =>
      this == ClueKind.missingSensor || this == ClueKind.sensorMask;
}

/// Panics sharing one clue, with when it started and what it points to.
class ClueGroup {
  ClueGroup({
    required this.kind,
    required this.value,
    required this.panics,
    this.component,
    this.note,
    required this.confidence,
    required this.isHardware,
  });

  final ClueKind kind;

  /// `TG0B`, `0x140000`, `thermalmonitord`, or a diagnosis title.
  final String value;

  /// Newest first.
  final List<AnalyzedPanic> panics;

  /// Suspected part, in the analysis language (null when unknown).
  final String? component;
  final String? note;
  final Confidence confidence;
  final bool isHardware;

  int get count => panics.length;
  DateTime? get first => panics
      .map((p) => p.date)
      .whereType<DateTime>()
      .fold(null, (a, d) => a == null || d.isBefore(a) ? d : a);
  DateTime? get last => panics
      .map((p) => p.date)
      .whereType<DateTime>()
      .fold(null, (a, d) => a == null || d.isAfter(a) ? d : a);
}

/// Groups panics by shared hardware clue (missing sensor, sensor mask,
/// watchdog service), then by diagnosis. A hardware clue seen 3 times or
/// more raises the confidence one level: one panic can be a fluke, the same
/// sensor failing again and again rarely is.
class Correlator {
  const Correlator(this.knowledgeBase, {this.lang = AppLang.en});

  final KnowledgeBase knowledgeBase;
  final AppLang lang;

  static final _checkins = RegExp(
    r'no successful checkins from ([A-Za-z0-9_.\-]+)',
    caseSensitive: false,
  );

  List<ClueGroup> correlate(List<AnalyzedPanic> panics) {
    final buckets = <(ClueKind, String), List<AnalyzedPanic>>{};
    void add(ClueKind k, String v, AnalyzedPanic p) =>
        buckets.putIfAbsent((k, v), () => []).add(p);

    for (final p in panics) {
      final r = p.report;
      var hasHardwareClue = false;
      for (final s in r.missingSensors) {
        add(ClueKind.missingSensor, s, p);
        hasHardwareClue = true;
      }
      if (r.sensorMask != null) {
        add(
          ClueKind.sensorMask,
          r.product == null
              ? r.sensorMaskHex!
              : '${r.sensorMaskHex} (${r.product})',
          p,
        );
        hasHardwareClue = true;
      }
      final service = _checkins.firstMatch(r.panicString ?? '')?.group(1);
      if (service != null && !hasHardwareClue) {
        add(ClueKind.watchdogService, service, p);
      } else if (!hasHardwareClue) {
        add(
          ClueKind.signature,
          p.result.isKnownSignature
              ? p.result.title
              : (r.signature ?? p.result.title),
          p,
        );
      }
    }

    final groups = [
      for (final e in buckets.entries) _group(e.key.$1, e.key.$2, e.value),
    ];
    groups.sort(_rank);
    return groups;
  }

  ClueGroup _group(ClueKind kind, String value, List<AnalyzedPanic> list) {
    list.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    var base = Confidence.none;
    for (final p in list) {
      if (p.result.confidence.rank > base.rank) base = p.result.confidence;
    }
    final hardware =
        kind.isHardwareClue || list.any((p) => p.result.isHardwareRelated);

    String? component, note;
    if (kind == ClueKind.missingSensor) {
      final info = knowledgeBase.sensor(value);
      component = info?.componentIn(lang);
      note = info?.noteIn(lang);
      // A mapped sensor is at least a medium-confidence clue.
      if (info != null && base.rank < Confidence.medium.rank) {
        base = Confidence.medium;
      }
    }
    component ??= _componentsOf(list);

    var confidence = base;
    if (hardware && list.length >= 3) confidence = _raise(confidence);
    return ClueGroup(
      kind: kind,
      value: value,
      panics: list,
      component: component,
      note: note,
      confidence: confidence,
      isHardware: hardware,
    );
  }

  /// Components named by the best-matching diagnosis of the group.
  static String? _componentsOf(List<AnalyzedPanic> list) {
    final known = list.where(
      (p) =>
          p.result.isKnownSignature && p.result.suspectedComponents.isNotEmpty,
    );
    if (known.isEmpty) return null;
    final best = known.reduce(
      (a, b) => b.result.confidence.rank > a.result.confidence.rank ? b : a,
    );
    return best.result.suspectedComponents.join(' / ');
  }

  static Confidence _raise(Confidence c) => switch (c) {
    Confidence.none => Confidence.low,
    Confidence.low => Confidence.medium,
    Confidence.medium || Confidence.high => Confidence.high,
  };

  /// Hardware clues first, then the most frequent, then the most recent.
  static int _rank(ClueGroup a, ClueGroup b) {
    if (a.isHardware != b.isHardware) return a.isHardware ? -1 : 1;
    final c = b.count.compareTo(a.count);
    if (c != 0) return c;
    final s = b.confidence.rank.compareTo(a.confidence.rank);
    if (s != 0) return s;
    final la = a.last, lb = b.last;
    if (la == null || lb == null) return 0;
    return lb.compareTo(la);
  }
}
