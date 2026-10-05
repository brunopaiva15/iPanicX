import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/lang_scope.dart';
import '../l10n/strings.dart';

import 'app_controller.dart';
import '../ui/shell.dart';
import 'theme.dart';

class IPaniXApp extends StatelessWidget {
  const IPaniXApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'iPaniX',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: controller.themeMode,
          locale: Locale(controller.language.name),
          supportedLocales: [for (final l in AppLang.values) Locale(l.name)],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) =>
              LangScope(lang: controller.language, child: child!),
          home: const AppShell(),
        ),
      ),
    );
  }
}
