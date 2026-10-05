import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/services/command_runner.dart';

void main() {
  const runner = ProcessCommandRunner();
  final posix = !Platform.isWindows;

  test('cancel kills the process', () async {
    final sw = Stopwatch()..start();
    await expectLater(
      runner.run('sleep', [
        '10',
      ], cancel: Future<void>.delayed(const Duration(milliseconds: 150))),
      throwsA(isA<CommandCancelledException>()),
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  }, skip: !posix);

  test('stream yields stdout lines and closes on exit', () async {
    final lines = await runner.stream('printf', ['a\\nb\\n']).toList();
    expect(lines, ['a', 'b']);
  }, skip: !posix);

  test('cancelling a stream subscription stops the process', () async {
    final first = await runner.stream('yes', ['line']).first;
    expect(first, 'line');
  }, skip: !posix);

  test('missing executable is reported on the stream', () async {
    await expectLater(
      runner.stream('/nonexistent/tool', const []).toList(),
      throwsA(isA<CommandNotFoundException>()),
    );
  });
}
