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

/// Battery values merged from every source iOS may answer, first hit wins
/// (same sources as iBatteryW):
///  * [ioreg]: `idevicediagnostics ioregentry AppleSmartBattery`;
///  * [gasGauge]: `idevicediagnostics diagnostics GasGauge` (cycle count,
///    design and full-charge capacity);
///  * [charger]: `idevicediagnostics ioregentry AppleARMPMUCharger` (older
///    iPhones, which have no AppleSmartBattery entry);
///  * [lockdown]: `ideviceinfo -q com.apple.mobile.battery` (charge level).
BatteryInfo? parseBattery({
  String? ioreg,
  String? gasGauge,
  String? charger,
  Map<String, String>? lockdown,
}) {
  final roots = [
    for (final xml in [ioreg, gasGauge, charger])
      if (xml != null) parsePlist(xml),
  ].whereType<Object>().toList();
  Object? find(String k) {
    for (final r in roots) {
      final v = plistFind(r, k);
      if (v != null) return v;
    }
    return null;
  }

  int? positive(Object? v) {
    final n = _int(v);
    return n != null && n > 0 ? n : null;
  }

  final design = positive(find('DesignCapacity'));
  final maxCap = _int(find('MaxCapacity'));
  // NominalChargeCapacity is what iOS Settings' "Maximum Capacity" uses.
  // In mAh only: iOS 26's GasGauge reports FullChargeCapacity as 100 (%).
  int? mAh(Object? v) {
    final n = positive(v);
    return n != null && n > 200 ? n : null;
  }

  final fullCharge =
      mAh(find('NominalChargeCapacity')) ??
      mAh(find('FullChargeCapacity')) ??
      mAh(find('AppleRawMaxCapacity')) ??
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

  double? temp;
  for (final r in roots) {
    temp ??= batteryTemperature(r);
  }

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

/// Battery temperature in °C. The key varies across iOS versions; values
/// are centi-degrees (2950 = 29.5 °C), Kelvin or plain degrees. Returns
/// null outside a plausible -20…90 °C range.
double? batteryTemperature(Object? root) {
  if (root == null) return null;
  for (final key in const [
    'Temperature',
    'VirtualTemperature',
    'BatteryTemperature',
    'CellTemperature',
  ]) {
    final raw = plistFind(root, key);
    final v = raw is double ? raw : _int(raw)?.toDouble();
    if (v == null) continue;
    // AppleSmartBattery uses centi-degrees Celsius (2950 = 29.5 °C).
    final c = v >= 1000
        ? v / 100
        : v > 200 && v < 380
        ? v -
              273.15 // Kelvin
        : v;
    if (c > -20 && c < 90) return double.parse(c.toStringAsFixed(1));
  }
  return null;
}

/// `ideviceinfo -q com.apple.disk_usage`.
///
/// iOS reports several "available" counters (`AmountDataAvailable`,
/// `TotalDataAvailable`…) that do not always agree: one can include
/// purgeable or reserved space. The smallest one is what the user can
/// actually use, as in iOS Settings.
StorageInfo? parseStorage(Map<String, String> values) {
  // TotalDiskCapacity is the size iOS Settings shows (256 GB); the data
  // partition alone (TotalDataCapacity) is smaller.
  final total =
      _int(values['TotalDiskCapacity']) ?? _int(values['TotalDataCapacity']);
  final candidates = [
    _int(values['AmountDataAvailable']),
    _int(values['TotalDataAvailable']),
  ].whereType<int>().where((v) => v >= 0).toList();
  if (total == null || total <= 0 || candidates.isEmpty) return null;
  final free = candidates.reduce((a, b) => a < b ? a : b);
  return StorageInfo(totalBytes: total, availableBytes: free.clamp(0, total));
}

/// One line per key, for the technical section (`Key: value`).
String rawValues(
  String label,
  Map<String, String> values, {
  Iterable<String>? only,
}) {
  final keys = (only ?? values.keys).where(values.containsKey).toList()..sort();
  if (keys.isEmpty) return '$label: (none)';
  String short(String v) => v.length > 120 ? '${v.substring(0, 117)}…' : v;
  return '$label:\n${keys.map((k) => '  $k: ${short(values[k]!)}').join('\n')}';
}

/// Keys and scalar values of an `idevicediagnostics` plist, for the
/// technical section.
String rawBatteryValues(String? xml, {String label = 'AppleSmartBattery'}) {
  final root = xml == null ? null : parsePlist(xml);
  if (root is! Map) return '$label: (none)';
  final out = <String, String>{};
  void walk(Map m, String prefix) {
    for (final e in m.entries) {
      final v = e.value;
      if (v is Map) {
        walk(v, '$prefix${e.key}.');
      } else if (v is! List) {
        out['$prefix${e.key}'] = '$v';
      }
    }
  }

  walk(root, '');
  return rawValues(label, out);
}

/// `ideviceinfo -q com.apple.security.mac.amfi` → `DeveloperModeStatus`.
bool? parseDeveloperMode(Map<String, String> values) =>
    _bool(values['DeveloperModeStatus']);

/// Output of `ideviceinfo -q com.apple.security.mac.amfi -k
/// DeveloperModeStatus`: the bare value (`true` / `false`), possibly after
/// libimobiledevice's "unknown domain" warning.
bool? parseDeveloperModeValue(String? out) {
  if (out == null) return null;
  for (final line in out.split('\n').reversed) {
    final value = line.contains(':') ? line.split(':').last : line;
    final v = _bool(value.trim());
    if (v != null) return v;
  }
  return null;
}
