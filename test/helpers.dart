import 'dart:io';

import 'package:ipanicx/diagnostics/knowledge_base.dart';

/// Real knowledge base shipped with the app.
KnowledgeBase loadKnowledgeBase() => KnowledgeBase.fromJsonString(
  File('assets/diagnostics/knowledge_base.json').readAsStringSync(),
);

String loadSample(String name) =>
    File('assets/samples/$name').readAsStringSync();

Future<String> sampleLoader(String name) async => loadSample(name);

const smcSample = 'panic-full-2026-10-04-174233.ips';
const unknownSample = 'panic-full-2026-09-28-091502.ips';
