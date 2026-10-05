import 'dart:convert';
import 'dart:io';

import '../app/host_platform.dart';

/// iPanicX's folder for local data:
///  * macOS: `~/Library/Application Support/iPanicX`
///  * Windows: `%APPDATA%\iPanicX`
///  * elsewhere: `~/.ipanicx`
Directory appSupportDir([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  if (HostPlatform.isWindows) {
    final appData = env['APPDATA'] ?? env['LOCALAPPDATA'] ?? '.';
    return Directory('$appData/iPanicX');
  }
  final home = env['HOME'] ?? '.';
  if (Platform.isMacOS) {
    return Directory('$home/Library/Application Support/iPanicX');
  }
  return Directory('$home/.ipanicx');
}

/// Small JSON key/value file (`settings.json`). Never throws: a missing or
/// unreadable file reads as empty.
class SettingsStore {
  SettingsStore({File? file})
    : file = file ?? File('${appSupportDir().path}/settings.json');

  final File file;

  Future<Map<String, Object?>> read() async {
    try {
      if (!await file.exists()) return {};
      final j = jsonDecode(await file.readAsString());
      return j is Map<String, dynamic> ? j : {};
    } catch (_) {
      return {};
    }
  }

  /// Merges [values] into the file. Returns false if it could not be written.
  Future<bool> write(Map<String, Object?> values) async {
    try {
      final all = {...await read(), ...values};
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(all));
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Settings store kept in memory (tests, mock mode).
class MemorySettingsStore extends SettingsStore {
  MemorySettingsStore([Map<String, Object?>? values])
    : _values = {...?values},
      super(file: File(''));

  final Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> read() async => {..._values};

  @override
  Future<bool> write(Map<String, Object?> values) async {
    _values.addAll(values);
    return true;
  }
}
