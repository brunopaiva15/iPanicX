import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/app/theme.dart';
import 'package:ipanicx/ui/kit.dart';
import 'package:ipanicx/ui/ring.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a button shows a spinner while its action runs', (tester) async {
    final done = Completer<void>();
    var taps = 0;
    await tester.pumpWidget(
      host(
        Btn(
          'Check Again',
          onPressed: () {
            taps++;
            return done.future;
          },
        ),
      ),
    );
    expect(find.byType(UsageRing), findsNothing);
    await tester.tap(find.text('Check Again'));
    await tester.pump();
    expect(find.byType(UsageRing), findsOneWidget);
    // Taps are ignored while busy.
    await tester.tap(find.text('Check Again'));
    expect(taps, 1);
    done.complete();
    await tester.pump(Btn.minBusy);
    await tester.pump();
    expect(find.byType(UsageRing), findsNothing);
  });

  testWidgets('a quick action still shows the spinner briefly', (tester) async {
    await tester.pumpWidget(host(Btn('Retry', onPressed: () async {})));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(UsageRing), findsOneWidget);
    await tester.pump(Btn.minBusy);
    await tester.pump();
    expect(find.byType(UsageRing), findsNothing);
  });

  testWidgets('synchronous actions: no spinner', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(Btn('Copy', onPressed: () => n++)));
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(n, 1);
    expect(find.byType(UsageRing), findsNothing);
  });
}
