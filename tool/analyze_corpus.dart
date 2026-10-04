// Analyses every report in a folder with the iPaniX engine, offline.
//
//   dart run tool/analyze_corpus.dart <folder-or-file> [...]
//
// Prints one line per file: bug type, product, diagnosis, confidence and the
// panic line. Useful to check new real-world panics against the knowledge
// base before adding rules. Accepts .ips, .txt, .log, .synced… (any text).
import 'dart:convert';
import 'dart:io';

import 'package:ipanix/diagnostics/knowledge_base.dart';
import 'package:ipanix/diagnostics/panic_analyzer.dart';
import 'package:ipanix/diagnostics/panic_parser.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/analyze_corpus.dart <folder|file>...');
    exit(64);
  }
  final kb = KnowledgeBase.fromJsonString(
    File('assets/diagnostics/knowledge_base.json').readAsStringSync(),
  );
  final analyzer = PanicAnalyzer(kb);
  const parser = PanicParser();

  final files = <File>[];
  for (final a in args) {
    final type = FileSystemEntity.typeSync(a);
    if (type == FileSystemEntityType.directory) {
      files.addAll(
        Directory(a)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => !f.uri.pathSegments.last.startsWith('.')),
      );
    } else if (type == FileSystemEntityType.file) {
      files.add(File(a));
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  final byTitle = <String, int>{};
  for (final f in files) {
    final sw = Stopwatch()..start();
    final text = utf8.decode(f.readAsBytesSync(), allowMalformed: true);
    final report = parser.parse(text);
    final result = analyzer.analyze(report);
    sw.stop();
    byTitle[result.title] = (byTitle[result.title] ?? 0) + 1;
    final name = f.uri.pathSegments.last;
    stdout.writeln(
      [
        name.length > 48 ? '${name.substring(0, 47)}…' : name.padRight(48),
        'bug=${report.bugType ?? '?'}'.padRight(8),
        (report.product ?? '?').padRight(11),
        'iOS ${report.osVersion ?? '?'}'.padRight(11),
        result.title.padRight(26),
        result.confidence.name.padRight(6),
        '${sw.elapsedMilliseconds}ms'.padLeft(6),
      ].join(' '),
    );
    stdout.writeln('    ${report.headline ?? '(no panic string)'}');
    if (report.parseWarnings.isNotEmpty) {
      stdout.writeln('    ! ${report.parseWarnings.join(' | ')}');
    }
  }
  stdout.writeln('\n${files.length} files');
  final sorted = byTitle.entries.toList()..sort((a, b) => b.value - a.value);
  for (final e in sorted) {
    stdout.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
  }
}
