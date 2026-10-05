import 'dart:io';

import '../app/host_platform.dart';

/// Finds the libimobiledevice executables.
///
/// Search order:
///  1. `IPANIX_TOOLS_DIR` environment variable;
///  2. tools embedded with the app:
///     - macOS: `iPaniX.app/Contents/Resources/libimobiledevice/bin`
///     - Windows: `<folder of iPaniX.exe>\libimobiledevice[\bin]`
///  3. package managers:
///     - macOS: Homebrew (`/opt/homebrew/bin`, `/usr/local/bin`), MacPorts
///     - Windows: MSYS2 (`C:\msys64\ucrt64\bin`, `mingw64\bin`, `clang64\bin`)
///  4. `PATH`.
class ToolLocator {
  ToolLocator({
    Map<String, String>? environment,
    String? resolvedExecutable,
    bool? isWindows,
  }) : _env = environment ?? Platform.environment,
       _exe = resolvedExecutable ?? Platform.resolvedExecutable,
       _windows = isWindows ?? HostPlatform.isWindows;

  final Map<String, String> _env;
  final String _exe;
  final bool _windows;

  static const required = ['idevice_id', 'ideviceinfo', 'idevicecrashreport'];

  String get _sep => _windows ? r'\' : '/';

  /// Parent folder of [path], whatever its separators.
  static String _parent(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final i = normalized.lastIndexOf('/');
    return i <= 0 ? normalized : normalized.substring(0, i);
  }

  /// Executable file name for [tool] on this OS.
  String executableName(String tool) => _windows ? '$tool.exe' : tool;

  List<String> get searchDirectories {
    final dirs = <String>[];
    final override = _env['IPANIX_TOOLS_DIR'];
    if (override != null && override.isNotEmpty) dirs.add(override);

    final exeDir = _parent(_exe);
    if (_windows) {
      dirs.add('$exeDir/libimobiledevice');
      dirs.add('$exeDir/libimobiledevice/bin');
      final drive = _env['SystemDrive'] ?? 'C:';
      for (final env in ['ucrt64', 'mingw64', 'clang64']) {
        dirs.add('$drive/msys64/$env/bin');
      }
      final programFiles = _env['ProgramFiles'];
      if (programFiles != null) dirs.add('$programFiles/libimobiledevice');
      final localAppData = _env['LOCALAPPDATA'];
      if (localAppData != null) {
        dirs.add('$localAppData/Programs/libimobiledevice');
      }
    } else {
      // <App>.app/Contents/MacOS/<exe> → <App>.app/Contents/Resources/…
      dirs.add('${_parent(exeDir)}/Resources/libimobiledevice/bin');
      dirs.addAll(['/opt/homebrew/bin', '/usr/local/bin', '/opt/local/bin']);
    }

    final path = _env['PATH'] ?? _env['Path'];
    if (path != null) {
      dirs.addAll(path.split(_windows ? ';' : ':').where((p) => p.isNotEmpty));
    }
    return dirs
        .map((d) => _windows ? d.replaceAll('/', _sep) : d)
        .toSet()
        .toList();
  }

  /// Absolute path of [tool], or null if not found.
  String? find(String tool) {
    final name = executableName(tool);
    for (final dir in searchDirectories) {
      final f = File('$dir$_sep$name');
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  /// Names of required tools that cannot be found.
  List<String> missingTools() =>
      required.where((t) => find(t) == null).toList();
}
