import 'package:flutter/widgets.dart';

import 'strings.dart';

/// Rebuilds every widget that reads `context.tr` when the language changes.
class LangScope extends InheritedWidget {
  const LangScope({super.key, required this.lang, required super.child});

  final AppLang lang;

  @override
  bool updateShouldNotify(LangScope oldWidget) => oldWidget.lang != lang;
}

extension LangContext on BuildContext {
  /// Strings of the active language; subscribes this widget to changes.
  Strings get tr {
    final scope = dependOnInheritedWidgetOfExactType<LangScope>();
    return Strings(scope?.lang ?? L10n.lang);
  }
}
