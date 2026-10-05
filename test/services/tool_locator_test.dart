import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/app/host_platform.dart';
import 'package:ipanicx/services/tool_locator.dart';

void main() {
  group('Windows', () {
    final locator = ToolLocator(
      isWindows: true,
      resolvedExecutable: r'C:\Program Files\iPanicX\iPanicX.exe',
      environment: {
        'SystemDrive': 'C:',
        'ProgramFiles': r'C:\Program Files',
        'LOCALAPPDATA': r'C:\Users\me\AppData\Local',
        'Path': r'C:\Windows\system32;C:\tools\imobiledevice;',
      },
    );

    test('looks for .exe tools', () {
      expect(locator.executableName('idevice_id'), 'idevice_id.exe');
    });

    test('searches next to iPanicX.exe first, then MSYS2, then Path', () {
      final dirs = locator.searchDirectories;
      expect(dirs.first, r'C:\Program Files\iPanicX\libimobiledevice');
      expect(dirs, contains(r'C:\Program Files\iPanicX\libimobiledevice\bin'));
      expect(dirs, contains(r'C:\msys64\ucrt64\bin'));
      expect(dirs, contains(r'C:\msys64\mingw64\bin'));
      expect(dirs, contains(r'C:\Program Files\libimobiledevice'));
      expect(dirs, contains(r'C:\tools\imobiledevice'));
      expect(
        dirs.indexOf(r'C:\msys64\ucrt64\bin'),
        lessThan(dirs.indexOf(r'C:\tools\imobiledevice')),
      );
      expect(dirs.every((d) => !d.contains('/')), isTrue);
    });

    test('IPANICX_TOOLS_DIR wins', () {
      final l = ToolLocator(
        isWindows: true,
        resolvedExecutable: r'C:\iPanicX\iPanicX.exe',
        environment: {'IPANICX_TOOLS_DIR': r'D:\idevice'},
      );
      expect(l.searchDirectories.first, r'D:\idevice');
    });
  });

  group('macOS', () {
    test('searches the app bundle, then Homebrew, then PATH', () {
      final l = ToolLocator(
        isWindows: false,
        resolvedExecutable: '/Applications/iPanicX.app/Contents/MacOS/iPanicX',
        environment: {'PATH': '/usr/bin:/custom/bin'},
      );
      final dirs = l.searchDirectories;
      expect(
        dirs.first,
        '/Applications/iPanicX.app/Contents/Resources/libimobiledevice/bin',
      );
      expect(
        dirs,
        containsAllInOrder([
          '/opt/homebrew/bin',
          '/usr/local/bin',
          '/usr/bin',
          '/custom/bin',
        ]),
      );
      expect(l.executableName('idevice_id'), 'idevice_id');
    });

    test('finds an existing tool', () {
      final tmp = Directory.systemTemp.createTempSync('ipanicx_loc_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File('${tmp.path}/ideviceinfo').writeAsStringSync('');
      final l = ToolLocator(
        isWindows: false,
        resolvedExecutable: '/x/y/z',
        environment: {'IPANICX_TOOLS_DIR': tmp.path, 'PATH': ''},
      );
      expect(l.find('ideviceinfo'), '${tmp.path}/ideviceinfo');
      expect(l.find('idevice_id'), isNull);
    });
  });

  test('host wording follows the platform', () {
    final saved = HostPlatform.isWindows;
    addTearDown(() => HostPlatform.isWindows = saved);
    HostPlatform.isWindows = true;
    expect(HostPlatform.computer, 'PC');
    expect(HostPlatform.revealLabel, 'Show in File Explorer');
    expect(HostPlatform.installCommand, contains('pacman'));
    expect(
      HostPlatform.usbServiceHint,
      contains('Apple Mobile Device Service'),
    );
    HostPlatform.isWindows = false;
    expect(HostPlatform.computer, 'Mac');
    expect(HostPlatform.revealLabel, 'Show in Finder');
    expect(HostPlatform.installCommand, 'brew install libimobiledevice');
  });
}
