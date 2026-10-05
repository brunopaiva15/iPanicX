import '../models/device_facts.dart';
import 'plist.dart';

/// Pure parsers for the read-only queries behind [DeviceFacts].

int? _int(Object? v) => switch (v) {
  int i => i,
  double d => d.round(),
  String s => int.tryParse(s.trim()),
  _ => null,
};

bool? _bool(Object? v) => switch (v) {
  bool b => b,
  String s when s.trim().toLowerCase() == 'true' => true,
  String s when s.trim().toLowerCase() == 'false' => false,
  _ => null,
};

/// `idevicediagnostics ioregentry AppleSmartBattery` (XML plist), merged
/// with the lockdown battery domain ([lockdown], `ideviceinfo -q
/// com.apple.mobile.battery`) for the charge level when IORegistry is not
/// available.
BatteryInfo? parseBattery({String? ioreg, Map<String, String>? lockdown}) {
  final root = ioreg == null ? null : parsePlist(ioreg);
  Object? find(String k) => root == null ? null : plistFind(root, k);

  final design = _int(find('DesignCapacity'));
  final maxCap = _int(find('MaxCapacity'));
  final fullCharge =
      _int(find('AppleRawMaxCapacity')) ??
      _int(find('NominalChargeCapacity')) ??
      // Older iOS: MaxCapacity in mAh (newer ones report 100, a percent).
      (maxCap != null && maxCap > 200 ? maxCap : null);

  int? charge;
  final current = _int(find('CurrentCapacity'));
  if (current != null && maxCap == 100) {
    charge = current;
  } else {
    final raw = _int(find('AppleRawCurrentCapacity')) ?? current;
    if (raw != null && fullCharge != null && fullCharge > 0) {
      charge = (raw * 100 / fullCharge).round().clamp(0, 100);
    }
  }
  charge ??= _int(lockdown?['BatteryCurrentCapacity']);

  final rawTemp = _int(find('Temperature'));
  // Centi-degrees Celsius (2950 = 29.5 °C).
  final temp = rawTemp == null
      ? null
      : (rawTemp > 1000 ? rawTemp / 100 : rawTemp.toDouble());

  final info = BatteryInfo(
    chargePercent: charge,
    cycleCount: _int(find('CycleCount')),
    designCapacity: design,
    fullChargeCapacity: fullCharge,
    temperatureC: temp == null || temp < -20 || temp > 90 ? null : temp,
    isCharging:
        _bool(find('IsCharging')) ?? _bool(lockdown?['BatteryIsCharging']),
  );
  return info.isEmpty ? null : info;
}

/// `ideviceinfo -q com.apple.disk_usage`.
StorageInfo? parseStorage(Map<String, String> values) {
  final total =
      _int(values['TotalDataCapacity']) ?? _int(values['TotalDiskCapacity']);
  final free =
      _int(values['TotalDataAvailable']) ?? _int(values['AmountDataAvailable']);
  if (total == null || free == null || total <= 0) return null;
  return StorageInfo(totalBytes: total, availableBytes: free.clamp(0, total));
}

/// `ideviceinfo -q com.apple.security.mac.amfi` → `DeveloperModeStatus`.
bool? parseDeveloperMode(Map<String, String> values) =>
    _bool(values['DeveloperModeStatus']);
