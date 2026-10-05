/// Minimal reader for Apple XML property lists, as printed by
/// `idevicediagnostics` (`ioregentry`, `diagnostics`).
///
/// Returns Dart values: `Map<String, Object?>`, `List<Object?>`, `String`,
/// `int`, `double`, `bool`, `DateTime`. Unknown or malformed parts become
/// `null`; it never throws.
Object? parsePlist(String xml) {
  final start = xml.indexOf('<plist');
  if (start < 0) return null;
  final body = xml.indexOf('>', start);
  if (body < 0) return null;
  try {
    final p = _PlistParser(xml, body + 1);
    return p.value();
  } catch (_) {
    return null;
  }
}

/// First value stored under [key] anywhere in [root] (depth-first, top
/// level first). Handy because iOS moves keys between the top level and
/// nested dicts (`BatteryData`) across versions.
Object? plistFind(Object? root, String key) {
  if (root is Map) {
    if (root.containsKey(key)) return root[key];
    for (final v in root.values) {
      final hit = plistFind(v, key);
      if (hit != null) return hit;
    }
  } else if (root is List) {
    for (final v in root) {
      final hit = plistFind(v, key);
      if (hit != null) return hit;
    }
  }
  return null;
}

class _PlistParser {
  _PlistParser(this.s, this.i);

  final String s;
  int i;

  static final _tag = RegExp(r'<\s*(/?)\s*([A-Za-z]+)\s*(/?)\s*>');

  Match? _nextTag() {
    final m = _tag.matchAsPrefix(s, _skipToTag());
    if (m != null) i = m.end;
    return m;
  }

  int _skipToTag() {
    while (i < s.length) {
      final lt = s.indexOf('<', i);
      if (lt < 0) return i = s.length;
      // Skip comments and processing instructions.
      if (s.startsWith('<!--', lt)) {
        final end = s.indexOf('-->', lt);
        i = end < 0 ? s.length : end + 3;
        continue;
      }
      if (s.startsWith('<?', lt) || s.startsWith('<!', lt)) {
        final end = s.indexOf('>', lt);
        i = end < 0 ? s.length : end + 1;
        continue;
      }
      return i = lt;
    }
    return i;
  }

  String _text(String name) {
    final end = s.indexOf('</$name', i);
    if (end < 0) throw const FormatException('unterminated');
    final raw = s.substring(i, end);
    i = s.indexOf('>', end) + 1;
    return _unescape(raw);
  }

  Object? value() {
    final m = _nextTag();
    if (m == null || m.group(1) == '/') return null;
    final name = m.group(2)!;
    final selfClosing = m.group(3) == '/';
    switch (name) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'dict':
        if (selfClosing) return <String, Object?>{};
        final map = <String, Object?>{};
        while (true) {
          final save = i;
          final t = _nextTag();
          if (t == null) return map;
          if (t.group(1) == '/' && t.group(2) == 'dict') return map;
          if (t.group(2) == 'key') {
            final key = _text('key');
            map[key] = value();
          } else {
            i = save;
            value(); // stray value: skip
          }
        }
      case 'array':
        if (selfClosing) return <Object?>[];
        final list = <Object?>[];
        while (true) {
          final save = i;
          final t = _nextTag();
          if (t == null) return list;
          if (t.group(1) == '/' && t.group(2) == 'array') return list;
          i = save;
          list.add(value());
        }
      case 'string':
        return selfClosing ? '' : _text('string');
      case 'integer':
        return selfClosing ? null : int.tryParse(_text('integer').trim());
      case 'real':
        return selfClosing ? null : double.tryParse(_text('real').trim());
      case 'date':
        return selfClosing ? null : DateTime.tryParse(_text('date').trim());
      case 'data':
        return selfClosing ? '' : _text('data').replaceAll(RegExp(r'\s'), '');
      default:
        if (!selfClosing) _text(name);
        return null;
    }
  }

  static String _unescape(String v) => v
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
