import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/models/device_facts.dart';
import 'package:ipanicx/services/device_facts_parser.dart';
import 'package:ipanicx/services/plist.dart';

void main() {
  final batteryXml = File(
    'test/fixtures/device/apple_smart_battery.plist',
  ).readAsStringSync();

  test('plist reader: nested dicts, scalars, comments, entities', () {
    final root = parsePlist(batteryXml) as Map;
    final reg = root['IORegistry'] as Map;
    expect(reg['AppleRawMaxCapacity'], 2491);
    expect(reg['BatteryInstalled'], isTrue);
    expect(reg['ExternalConnected'], isFalse);
    expect(reg['Name'], 'AppleSmartBattery & co');
    expect((reg['BatteryData'] as Map)['Serial'], 'F5D1234ABCD');
    expect(plistFind(root, 'DesignCapacity'), 3274);
    expect(parsePlist('ERROR: Could not connect'), isNull);
    expect(
      parsePlist('<plist><array><real>1.5</real><string/></array></plist>'),
      [1.5, ''],
    );
  });

  test('AppleSmartBattery → battery info', () {
    final b = parseBattery(ioreg: batteryXml)!;
    expect(b.cycleCount, 843);
    expect(b.designCapacity, 3274);
    expect(b.fullChargeCapacity, 2491);
    expect(b.healthPercent, 76);
    expect(b.chargePercent, 72);
    expect(b.temperatureC, 29.5);
    expect(b.isCharging, isFalse);
  });

  test('older iOS: MaxCapacity in mAh, raw charge', () {
    const xml =
        '<plist><dict><key>MaxCapacity</key><integer>1500</integer>'
        '<key>CurrentCapacity</key><integer>750</integer>'
        '<key>DesignCapacity</key><integer>1810</integer></dict></plist>';
    final b = parseBattery(ioreg: xml)!;
    expect(b.fullChargeCapacity, 1500);
    expect(b.chargePercent, 50);
    expect(b.healthPercent, 83);
  });

  test('no IORegistry: lockdown battery domain only, never invented', () {
    final b = parseBattery(
      ioreg: null,
      lockdown: {'BatteryCurrentCapacity': '64', 'BatteryIsCharging': 'true'},
    )!;
    expect(b.chargePercent, 64);
    expect(b.isCharging, isTrue);
    expect(b.healthPercent, isNull);
    expect(b.cycleCount, isNull);
    expect(parseBattery(ioreg: null, lockdown: {}), isNull);
  });

  test('disk usage and developer mode', () {
    final s = parseStorage({
      'TotalDiskCapacity': '128000000000',
      'TotalDataCapacity': '119000000000',
      'TotalDataAvailable': '7140000000',
    })!;
    expect(s.totalBytes, 119000000000);
    expect(s.usedPercent, 94);
    expect(parseStorage({}), isNull);
    expect(parseDeveloperMode({'DeveloperModeStatus': 'true'}), isTrue);
    expect(parseDeveloperMode({}), isNull);
    expect(const StorageInfo(totalBytes: 0, availableBytes: 0).usedPercent, 0);
  });
}
