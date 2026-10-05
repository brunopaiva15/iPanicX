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
    // NominalChargeCapacity (iOS Settings' "Maximum Capacity") wins over
    // AppleRawMaxCapacity.
    expect(b.fullChargeCapacity, 2523);
    expect(b.healthPercent, 77);
    expect(b.chargePercent, 72);
    expect(b.temperatureC, 29.5);
    expect(b.isCharging, isFalse);
  });

  test('GasGauge diagnostics fill what AppleSmartBattery lacks', () {
    const gasGauge =
        '<?xml version="1.0"?><plist version="1.0"><dict>'
        '<key>GasGauge</key><dict>'
        '<key>CycleCount</key><integer>512</integer>'
        '<key>DesignCapacity</key><integer>3200</integer>'
        '<key>FullChargeCapacity</key><integer>2880</integer>'
        '<key>Status</key><string>Success</string>'
        '</dict></dict></plist>';
    const ioreg =
        '<plist><dict><key>IORegistry</key><dict>'
        '<key>CurrentCapacity</key><integer>55</integer>'
        '<key>MaxCapacity</key><integer>100</integer>'
        '<key>VirtualTemperature</key><integer>3120</integer>'
        '</dict></dict></plist>';
    final b = parseBattery(ioreg: ioreg, gasGauge: gasGauge)!;
    expect(b.cycleCount, 512);
    expect(b.designCapacity, 3200);
    expect(b.fullChargeCapacity, 2880);
    expect(b.healthPercent, 90);
    expect(b.chargePercent, 55);
    expect(b.temperatureC, 31.2);
    // GasGauge alone is enough.
    expect(parseBattery(gasGauge: gasGauge)!.healthPercent, 90);
  });

  test('older iPhones: AppleARMPMUCharger entry', () {
    const charger =
        '<plist><dict><key>IORegistry</key><dict>'
        '<key>MaxCapacity</key><integer>1520</integer>'
        '<key>DesignCapacity</key><integer>1810</integer>'
        '<key>CycleCount</key><integer>301</integer>'
        '<key>Temperature</key><integer>2875</integer>'
        '</dict></dict></plist>';
    final b = parseBattery(
      ioreg: 'ERROR: Unable to retrieve IORegistry from device.',
      charger: charger,
    )!;
    expect(b.fullChargeCapacity, 1520);
    expect(b.healthPercent, 84);
    expect(b.cycleCount, 301);
    expect(b.temperatureC, 28.8);
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
    // TotalDiskCapacity: the size iOS Settings shows.
    expect(s.totalBytes, 128000000000);
    expect(s.usedPercent, 94);
    expect(parseStorage({}), isNull);
    expect(parseDeveloperMode({'DeveloperModeStatus': 'true'}), isTrue);
    expect(parseDeveloperMode({}), isNull);
    expect(const StorageInfo(totalBytes: 0, availableBytes: 0).usedPercent, 0);
  });

  test('free space: the smallest counter iOS reports', () {
    // Reported on a real iPhone: TotalDataAvailable counted space that is
    // not actually free; Settings showed ~13 GB.
    final s = parseStorage({
      'TotalDiskCapacity': '256000000000',
      'TotalDataCapacity': '235000000000',
      'TotalDataAvailable': '129000000000',
      'AmountDataAvailable': '13000000000',
    })!;
    expect(s.availableBytes, 13000000000);
    expect(s.totalBytes, 256000000000);
    expect(s.usedPercent, 95);
  });

  test('iPhone 14 Pro on iOS 26 (real values): battery and storage', () {
    // Values reported by a real device (serial and blobs left out).
    const ioreg =
        '<plist><dict><key>IORegistry</key><dict>'
        '<key>BatteryData</key><dict>'
        '<key>AppleRawMaxCapacity</key><integer>3107</integer>'
        '<key>CurrentCapacity</key><integer>12</integer>'
        '<key>DesignCapacity</key><integer>3544</integer>'
        '<key>FullChargeCapacity</key><integer>3107</integer>'
        '<key>MaxCapacity</key><integer>100</integer>'
        '<key>NominalChargeCapacity</key><integer>3075</integer>'
        '</dict>'
        '<key>CurrentCapacity</key><integer>12</integer>'
        '<key>CycleCount</key><integer>950</integer>'
        '<key>IsCharging</key><false/>'
        '<key>MaxCapacity</key><integer>100</integer>'
        '<key>DeadBatteryBootData</key><dict><key>GeneralPayload</key><dict>'
        '<key>AverageBattSkinTemp</key><integer>0</integer>'
        '</dict></dict>'
        '</dict></dict></plist>';
    const gasGauge =
        '<plist><dict><key>GasGauge</key><dict>'
        '<key>CycleCount</key><integer>950</integer>'
        '<key>FullChargeCapacity</key><integer>100</integer>'
        '<key>Status</key><string>Success</string>'
        '</dict></dict></plist>';
    final b = parseBattery(ioreg: ioreg, gasGauge: gasGauge)!;
    expect(b.designCapacity, 3544);
    expect(b.fullChargeCapacity, 3075);
    expect(b.healthPercent, 87);
    expect(b.cycleCount, 950);
    expect(b.chargePercent, 12);
    expect(b.isCharging, isFalse);
    expect(b.temperatureC, isNull, reason: 'iOS 26 sends none');
    // GasGauge alone: FullChargeCapacity 100 is a percent, not mAh.
    expect(parseBattery(gasGauge: gasGauge)!.fullChargeCapacity, isNull);

    final s = parseStorage({
      'AmountDataAvailable': '6045429760',
      'TotalDataAvailable': '127277871104',
      'TotalDataCapacity': '235267575808',
      'TotalDiskCapacity': '256000000000',
    })!;
    expect(s.totalBytes, 256000000000);
    expect(s.availableBytes, 6045429760);
    expect(s.usedPercent, 98);
  });

  test('developer mode: bare value from -k DeveloperModeStatus', () {
    expect(parseDeveloperModeValue('true\n'), isTrue);
    expect(
      parseDeveloperModeValue(
        'WARNING: Sending query with unknown domain '
        '"com.apple.security.mac.amfi".\nfalse\n',
      ),
      isFalse,
    );
    expect(parseDeveloperModeValue('DeveloperModeStatus: true'), isTrue);
    expect(parseDeveloperModeValue(''), isNull);
    expect(parseDeveloperModeValue(null), isNull);
  });

  test('long raw values are shortened', () {
    final r = rawValues('disk_usage', {'NANDInfo': 'A' * 5000});
    expect(r.length, lessThan(200));
    expect(r, endsWith('…'));
  });

  test('battery temperature: key and unit variants', () {
    double? t(String key, String value) => batteryTemperature(
      parsePlist(
        '<plist><dict><key>$key</key><integer>$value</integer></dict></plist>',
      ),
    );
    expect(t('Temperature', '2950'), 29.5);
    expect(t('VirtualTemperature', '3105'), 31.1);
    expect(t('BatteryTemperature', '30'), 30);
    expect(t('Temperature', '303'), 29.9); // Kelvin
    expect(t('Temperature', '99999'), isNull);
    expect(t('Voltage', '3900'), isNull);
  });

  test('raw values for the technical section', () {
    expect(
      rawValues('disk_usage', {'B': '2', 'A': '1'}),
      'disk_usage:\n  A: 1\n  B: 2',
    );
    expect(
      rawBatteryValues(batteryXml),
      contains('IORegistry.BatteryData.CycleCount: 843'),
    );
    expect(rawBatteryValues(null), 'AppleSmartBattery: (none)');
  });
}
