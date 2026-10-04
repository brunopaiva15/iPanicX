import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CommandResult {
  const CommandResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;

  /// stdout + stderr, used for error classification and technical details.
  String get combined =>
      [stdout.trim(), stderr.trim()].where((s) => s.isNotEmpty).join('\n');
}

class CommandNotFoundException implements Exception {
  const CommandNotFoundException(this.executable, this.details);
  final String executable;
  final String details;
  @override
  String toString() => 'Command not found: $executable ($details)';
}

class CommandTimeoutException implements Exception {
  const CommandTimeoutException(
    this.executable,
    this.timeout,
    this.partialOutput,
  );
  final String executable;
  final Duration timeout;
  final String partialOutput;
  @override
  String toString() =>
      'Command timed out after ${timeout.inSeconds}s: $executable';
}

/// Runs external executables. Abstracted so the libimobiledevice service can
/// be unit-tested and later replaced by an FFI / native implementation.
abstract class CommandRunner {
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 15),
    void Function(String line)? onStdoutLine,
  });
}

class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner();

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 15),
    void Function(String line)? onStdoutLine,
  }) async {
    final Process process;
    try {
      process = await Process.start(executable, arguments);
    } on ProcessException catch (e) {
      throw CommandNotFoundException(executable, e.message);
    }
    final out = StringBuffer();
    final err = StringBuffer();
    final outDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
          out.writeln(line);
          onStdoutLine?.call(line);
        })
        .asFuture<void>();
    final errDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(err.write)
        .asFuture<void>();

    final int code;
    try {
      code = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw CommandTimeoutException(executable, timeout, '$out$err');
    }
    await Future.wait([outDone, errDone])
        .timeout(const Duration(seconds: 2), onTimeout: () => const []);
    return CommandResult(code, out.toString(), err.toString());
  }
}
