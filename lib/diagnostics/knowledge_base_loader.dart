import 'package:flutter/services.dart' show rootBundle;

import 'knowledge_base.dart';

/// Loads the bundled knowledge base (kept apart from [KnowledgeBase] so the
/// diagnostics engine stays pure Dart and usable from `tool/`).
Future<KnowledgeBase> loadKnowledgeBaseFromAssets() async {
  final source = await rootBundle.loadString(KnowledgeBase.assetPath);
  return KnowledgeBase.fromJsonString(source);
}
