import 'dart:convert';

import '../l10n/strings.dart';
import '../models/diagnostic_result.dart';
import 'diagnostic_rule.dart';

/// Part that usually carries a sensor reported as missing by
/// thermalmonitord (`"sensors"` in the JSON).
class SensorInfo {
  const SensorInfo({required this.component, this.fr, this.note, this.noteFr});

  final String component;
  final String? fr;
  final String? note;
  final String? noteFr;

  String componentIn(AppLang lang) =>
      lang == AppLang.fr ? (fr ?? component) : component;
  String? noteIn(AppLang lang) => lang == AppLang.fr ? (noteFr ?? note) : note;
}

/// Public reference a rule, mask or sensor is based on (`"sources"`).
class KbSource {
  const KbSource({required this.title, required this.url});
  final String title;
  final String url;

  @override
  String toString() => '$title — $url';
}

/// One code of the per-model SMC sensor-mask table.
class SmcCode {
  const SmcCode({
    required this.mask,
    required this.part,
    this.sources = const [],
    this.confidence = Confidence.high,
    this.exactOnly = false,
    this.note,
    this.noteFr,
  });

  final int mask;

  /// Key of [KnowledgeBase.parts].
  final String part;
  final List<String> sources;
  final Confidence confidence;

  /// Overlaps the bits of other codes: only counts as an exact match
  /// (0x500000 on iPhone 14 is the battery, not coil + charge port).
  final bool exactOnly;
  final String? note;
  final String? noteFr;

  String? noteIn(AppLang lang) => lang == AppLang.fr ? (noteFr ?? note) : note;
}

/// Codes of one model family (`"smcSensorMasks"`).
class SmcModel {
  const SmcModel({
    required this.model,
    required this.devices,
    required this.codes,
  });
  final String model;
  final List<String> devices;
  final List<SmcCode> codes;
}

/// What an SMC sensor mask means on a given model.
class SmcDecode {
  const SmcDecode({
    required this.model,
    required this.mask,
    required this.hits,
    this.unknownBits = 0,
    this.alternative = const [],
    required this.confidence,
  });

  /// Model family name, e.g. "iPhone 14 Pro / 14 Pro Max".
  final String model;
  final int mask;

  /// Codes the mask is made of. Empty when nothing is referenced.
  final List<SmcCode> hits;

  /// Bits of [mask] no code explains.
  final int unknownBits;

  /// Other reading of an exact, overlapping code (see [SmcCode.exactOnly]).
  final List<SmcCode> alternative;
  final Confidence confidence;

  bool get isMapped => hits.isNotEmpty;

  Set<String> get sourceKeys => {
    for (final c in [...hits, ...alternative]) ...c.sources,
  };
}

/// Panic signatures known to iPanicX.
///
/// Built from public repair references (see `sources`); **not** exhaustive.
class KnowledgeBase {
  const KnowledgeBase({
    required this.rules,
    this.version,
    this.warnings = const [],
    this.sensors = const {},
    this.sources = const {},
    this.parts = const {},
    this.smcMasks = const [],
  });

  static const assetPath = 'assets/diagnostics/knowledge_base.json';

  final List<DiagnosticRule> rules;
  final String? version;

  /// Rules that were skipped because they are malformed.
  final List<String> warnings;

  /// Sensor name (lower case) → part.
  final Map<String, SensorInfo> sensors;

  SensorInfo? sensor(String name) => sensors[name.toLowerCase()];

  final Map<String, KbSource> sources;

  /// Part key → language code → name.
  final Map<String, Map<String, String>> parts;
  final List<SmcModel> smcMasks;

  String partName(String key, AppLang lang) =>
      parts[key]?[lang.name] ?? parts[key]?['en'] ?? key;

  /// Resolved [keys], unknown ones skipped, duplicates removed.
  List<KbSource> sourcesFor(Iterable<String> keys) => [
    for (final k in keys.toSet())
      if (sources[k] != null) sources[k]!,
  ];

  /// Reads [mask] with the SMC table of [product]. Null when the model is
  /// not in the table.
  ///
  /// An exact code wins; otherwise the mask is split into codes, larger
  /// ones first (0x700000 on iPhone 15 Pro = 0x300000 + 0x400000).
  SmcDecode? decodeSmcMask(String? product, int? mask) {
    if (mask == null || mask == 0) return null;
    final families = smcMasks
        .where((m) => DiagnosticRule.deviceIn(m.devices, product))
        .toList();
    if (families.isEmpty) return null;
    final model = families.first.model;
    final codes = [for (final f in families) ...f.codes];

    List<SmcCode> split(int value, Iterable<SmcCode> from) {
      final pool = from.where((c) => !c.exactOnly).toList()
        ..sort((a, b) {
          final n = _bits(b.mask).compareTo(_bits(a.mask));
          return n != 0 ? n : b.mask.compareTo(a.mask);
        });
      final out = <SmcCode>[];
      var rest = value;
      for (final c in pool) {
        if (rest & c.mask == c.mask) {
          out.add(c);
          rest &= ~c.mask;
        }
      }
      return rest == 0 || out.isEmpty ? out : [...out, _rest(rest)];
    }

    final exact = codes.where((c) => c.mask == mask).toList();
    if (exact.isNotEmpty) {
      var alternative = <SmcCode>[];
      if (exact.any((c) => c.exactOnly)) {
        final other = split(mask, codes.where((c) => !exact.contains(c)));
        if (other.isNotEmpty && other.every((c) => c.part.isNotEmpty)) {
          alternative = other..sort((a, b) => a.mask.compareTo(b.mask));
        }
      }
      var confidence = _lowest(exact);
      if (alternative.isNotEmpty) {
        confidence = _cap(confidence, Confidence.medium);
      }
      return SmcDecode(
        model: model,
        mask: mask,
        hits: exact,
        alternative: alternative,
        confidence: confidence,
      );
    }

    final parts = split(mask, codes);
    final known = parts.where((c) => c.part.isNotEmpty).toList()
      ..sort((a, b) => a.mask.compareTo(b.mask));
    final unknown = parts.length == known.length ? 0 : parts.last.mask;
    if (known.isEmpty) {
      return SmcDecode(
        model: model,
        mask: mask,
        hits: const [],
        unknownBits: mask,
        confidence: Confidence.none,
      );
    }
    var confidence = _lowest(known);
    if (unknown != 0) confidence = _cap(confidence, Confidence.medium);
    return SmcDecode(
      model: model,
      mask: mask,
      hits: known,
      unknownBits: unknown,
      confidence: confidence,
    );
  }

  /// Placeholder for bits no code explains (empty part).
  static SmcCode _rest(int bits) => SmcCode(mask: bits, part: '');

  static int _bits(int v) {
    var n = 0;
    for (var x = v; x != 0; x &= x - 1) {
      n++;
    }
    return n;
  }

  static Confidence _lowest(List<SmcCode> codes) =>
      codes.map((c) => c.confidence).reduce((a, b) => a.rank <= b.rank ? a : b);

  static Confidence _cap(Confidence c, Confidence max) =>
      c.rank > max.rank ? max : c;

  static const empty = KnowledgeBase(rules: []);

  factory KnowledgeBase.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Knowledge base must be a JSON object.');
    }
    final rules = <DiagnosticRule>[];
    final warnings = <String>[];
    final rawRules = decoded['rules'];
    if (rawRules is List) {
      for (var i = 0; i < rawRules.length; i++) {
        final r = rawRules[i];
        try {
          if (r is! Map<String, dynamic>) {
            throw const FormatException('not an object');
          }
          final rule = DiagnosticRule.fromJson(r);
          if (!rule.hasCriteria) {
            throw const FormatException('rule has no matching criteria');
          }
          rules.add(rule);
        } on FormatException catch (e) {
          warnings.add('Rule #$i skipped: ${e.message}');
        }
      }
    }
    final sensors = <String, SensorInfo>{};
    final rawSensors = decoded['sensors'];
    if (rawSensors is Map<String, dynamic>) {
      for (final e in rawSensors.entries) {
        final v = e.value;
        if (e.key.startsWith('_') || v is! Map<String, dynamic>) continue;
        final component = v['component']?.toString();
        if (component == null) continue;
        sensors[e.key.toLowerCase()] = SensorInfo(
          component: component,
          fr: v['fr']?.toString(),
          note: v['note']?.toString(),
          noteFr: v['noteFr']?.toString(),
        );
      }
    }
    final sources = <String, KbSource>{};
    final rawSources = decoded['sources'];
    if (rawSources is Map<String, dynamic>) {
      for (final e in rawSources.entries) {
        final v = e.value;
        if (e.key.startsWith('_') || v is! Map<String, dynamic>) continue;
        final url = v['url']?.toString();
        if (url == null) continue;
        sources[e.key] = KbSource(
          title: v['title']?.toString() ?? url,
          url: url,
        );
      }
    }
    final parts = <String, Map<String, String>>{};
    final rawParts = decoded['parts'];
    if (rawParts is Map<String, dynamic>) {
      for (final e in rawParts.entries) {
        final v = e.value;
        if (e.key.startsWith('_') || v is! Map<String, dynamic>) continue;
        parts[e.key] = {
          for (final n in v.entries)
            if (n.value is String) n.key: n.value as String,
        };
      }
    }
    final smcMasks = <SmcModel>[];
    final rawMasks = decoded['smcSensorMasks'];
    if (rawMasks is List) {
      for (var i = 0; i < rawMasks.length; i++) {
        final m = rawMasks[i];
        final devices = m is Map ? m['devices'] : null;
        final codes = m is Map ? m['codes'] : null;
        if (devices is! List || codes is! List) {
          warnings.add('SMC mask table #$i skipped: needs devices and codes');
          continue;
        }
        final parsed = <SmcCode>[];
        for (final c in codes) {
          final mask = c is Map ? DiagnosticRule.parseMask(c['mask']) : null;
          final part = c is Map ? c['part']?.toString() : null;
          if (mask == null || mask == 0 || part == null || part.isEmpty) {
            warnings.add('SMC mask table #$i: code skipped');
            continue;
          }
          final src = c['sources'];
          parsed.add(
            SmcCode(
              mask: mask,
              part: part,
              sources: src is List ? src.map((e) => '$e').toList() : const [],
              confidence: c['confidence'] == null
                  ? Confidence.high
                  : Confidence.parse(c['confidence'].toString()),
              exactOnly: c['exactOnly'] == true,
              note: c['note']?.toString(),
              noteFr: c['noteFr']?.toString(),
            ),
          );
        }
        smcMasks.add(
          SmcModel(
            model: m['model']?.toString() ?? devices.join(', '),
            devices: devices.map((e) => '$e').toList(),
            codes: parsed,
          ),
        );
      }
    }
    return KnowledgeBase(
      rules: rules,
      version: decoded['version']?.toString(),
      warnings: warnings,
      sensors: sensors,
      sources: sources,
      parts: parts,
      smcMasks: smcMasks,
    );
  }
}
