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

class CommandCancelledException implements Exception {
  const CommandCancelledException(this.executable);
  final String executable;
  @override
  String toString() => 'Command cancelled: $executable';
}

/// Runs external executables. Abstracted so the libimobiledevice service can
/// be unit-tested and later replaced by an FFI / native implementation.
abstract class CommandRunner {
  /// Runs to completion. Completing [cancel] kills the process and throws
  /// [CommandCancelledException].
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 15),
    void Function(String line)? onStdoutLine,
    Future<void>? cancel,
  });

  /// Long-running process (e.g. `idevicesyslog`) as a stream of stdout lines.
  /// Cancelling the subscription kills the process; the stream closes when
  /// the process exits.
  Stream<String> stream(String executable, List<String> arguments);
}

class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner();

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 15),
    void Function(String line)? onStdoutLine,
    Future<void>? cancel,
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

    var cancelled = false;
    cancel?.then((_) {
      cancelled = true;
      process.kill(ProcessSignal.sigkill);
    });
    final int code;
    try {
      code = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw CommandTimeoutException(executable, timeout, '$out$err');
    }
    if (cancelled) throw CommandCancelledException(executable);
    await Future.wait([
      outDone,
      errDone,
    ]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
    return CommandResult(code, out.toString(), err.toString());
  }

  @override
  Stream<String> stream(String executable, List<String> arguments) {
    Process? process;
    StreamSubscription<String>? sub;
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () async {
        try {
          process = await Process.start(executable, arguments);
        } on ProcessException catch (e) {
          controller.addError(CommandNotFoundException(executable, e.message));
          await controller.close();
          return;
        }
        // stderr must be drained or the child can block on a full pipe.
        process!.stderr.drain<void>();
        sub = process!.stdout
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen(
              controller.add,
              onDone: () => controller.close(),
              onError: controller.addError,
            );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () async {
        process?.kill(ProcessSignal.sigkill);
        await sub?.cancel();
      },
    );
    return controller.stream;
  }
}
