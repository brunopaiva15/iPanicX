import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanix/diagnostics/panic_analyzer.dart';
import 'package:ipanix/diagnostics/panic_parser.dart';

import '../helpers.dart';

/// Robustness check over full real-world reports.
///
/// Populate with `scripts/fetch_real_samples.sh` (or drop your own reports in
/// test/fixtures/real_full/). Skipped when the folder is absent.
void main() {
  final dir = Directory('test/fixtures/real_full');
  final files = dir.existsSync()
      ? dir.listSync(recursive: true).whereType<File>().toList()
      : <File>[];

  test('every real report parses and analyses without throwing', () {
    const parser = PanicParser();
    final analyzer = PanicAnalyzer(loadKnowledgeBase());
    for (final f in files) {
      final text = utf8.decode(f.readAsBytesSync(), allowMalformed: true);
      final report = parser.parse(text);
      final result = analyzer.analyze(report);
      expect(result.title, isNotEmpty, reason: f.path);
      if (report.bugType == '210' || report.bugType == '151') {
        expect(report.hasPanicString, isTrue, reason: f.path);
        expect(report.product, isNotNull, reason: f.path);
        expect(report.osVersion, isNotNull, reason: f.path);
      }
    }
  }, skip: files.isEmpty ? 'test/fixtures/real_full is empty' : false);
}
