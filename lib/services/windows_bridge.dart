import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'platform_bridge.dart';

/// Windows implementation of [PlatformBridge].
///
/// Dialogs use the official `file_selector` plugin (IFileOpenDialog /
/// IFileSaveDialog). USB arrivals are picked up by the 2-second device poll,
/// so no native watcher is needed in V0.
class WindowsBridge implements PlatformBridge {
  const WindowsBridge();

  @override
  Stream<void> get usbDeviceEvents => const Stream.empty();

  @override
  Future<String?> saveTextFile({
    required String suggestedName,
    required String contents,
  }) async {
    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Text', extensions: ['txt']),
        ],
      );
      if (location == null) return null;
      var path = location.path;
      if (!path.toLowerCase().endsWith('.txt')) path = '$path.txt';
      await File(path).writeAsString(contents);
      return path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> pickIpsFile() async {
    try {
      // .ips reports are often shared as .txt / .log / .synced: allow all.
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Panic reports', extensions: ['ips', 'txt', 'log']),
          XTypeGroup(label: 'All files'),
        ],
      );
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> revealInFinder(String path) async {
    final native = path.replaceAll('/', r'\');
    final type = FileSystemEntity.typeSync(native);
    if (type == FileSystemEntityType.notFound) return false;
    try {
      // `explorer /select, "<path>"` highlights the file. explorer.exe
      // returns 1 even on success, so the exit code is not checked.
      await Process.run(
        'explorer.exe',
        type == FileSystemEntityType.file ? ['/select,', native] : [native],
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
