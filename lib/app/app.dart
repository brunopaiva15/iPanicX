import 'package:flutter/material.dart';

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
          home: const AppShell(),
        ),
      ),
    );
  }
}
