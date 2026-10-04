import 'dart:io';

/// Finds the libimobiledevice executables.
///
/// Search order:
///  1. `IPANIX_TOOLS_DIR` environment variable;
///  2. tools embedded in the app bundle
///     (`iPaniX.app/Contents/Resources/libimobiledevice/bin`);
///  3. Homebrew (`/opt/homebrew/bin`, `/usr/local/bin`) and MacPorts;
///  4. `PATH`.
class ToolLocator {
  ToolLocator({Map<String, String>? environment, String? resolvedExecutable})
    : _env = environment ?? Platform.environment,
      _exe = resolvedExecutable ?? Platform.resolvedExecutable;

  final Map<String, String> _env;
  final String _exe;

  static const required = ['idevice_id', 'ideviceinfo', 'idevicecrashreport'];

  List<String> get searchDirectories {
    final dirs = <String>[];
    final override = _env['IPANIX_TOOLS_DIR'];
    if (override != null && override.isNotEmpty) dirs.add(override);
    // <App>.app/Contents/MacOS/<exe> → <App>.app/Contents/Resources/…
    final contents = File(_exe).parent.parent.path;
    dirs.add('$contents/Resources/libimobiledevice/bin');
    dirs.addAll(['/opt/homebrew/bin', '/usr/local/bin', '/opt/local/bin']);
    final path = _env['PATH'];
    if (path != null) {
      dirs.addAll(path.split(':').where((p) => p.isNotEmpty));
    }
    return dirs.toSet().toList();
  }

  /// Absolute path of [tool], or null if not found.
  String? find(String tool) {
    for (final dir in searchDirectories) {
      final f = File('$dir/$tool');
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  /// Names of required tools that cannot be found.
  List<String> missingTools() =>
      required.where((t) => find(t) == null).toList();
}
