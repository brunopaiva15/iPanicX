/// Battery values from `AppleSmartBattery` (IORegistry) and the lockdown
/// battery domain. Every field is optional: iOS does not expose all of them
/// on every version, and iPanicX never invents a value.
class BatteryInfo {
  const BatteryInfo({
    this.chargePercent,
    this.cycleCount,
    this.designCapacity,
    this.fullChargeCapacity,
    this.temperatureC,
    this.isCharging,
  });

  final int? chargePercent;
  final int? cycleCount;

  /// mAh, as designed.
  final int? designCapacity;

  /// mAh the battery holds when full today.
  final int? fullChargeCapacity;
  final double? temperatureC;
  final bool? isCharging;

  /// Full-charge capacity / design capacity, in percent.
  int? get healthPercent {
    final d = designCapacity, f = fullChargeCapacity;
    if (d == null || f == null || d <= 0 || f <= 0) return null;
    final v = (f * 100 / d).round();
    return v.clamp(0, 110);
  }

  bool get isEmpty =>
      chargePercent == null &&
      cycleCount == null &&
      designCapacity == null &&
      fullChargeCapacity == null &&
      temperatureC == null;

  Map<String, Object?> toJson() => {
    'chargePercent': chargePercent,
    'cycleCount': cycleCount,
    'designCapacity': designCapacity,
    'fullChargeCapacity': fullChargeCapacity,
    'temperatureC': temperatureC,
    'isCharging': isCharging,
  };
}

class StorageInfo {
  const StorageInfo({required this.totalBytes, required this.availableBytes});

  final int totalBytes;
  final int availableBytes;

  int get usedBytes => (totalBytes - availableBytes).clamp(0, totalBytes);
  int get usedPercent =>
      totalBytes <= 0 ? 0 : (usedBytes * 100 / totalBytes).round();
}

/// What the connected iPhone reports about itself (read-only queries).
class DeviceFacts {
  const DeviceFacts({
    this.battery,
    this.storage,
    this.developerMode,
    this.basebandVersion,
    this.wifiAddress,
    this.notes = const [],
    this.readAt,
  });

  final BatteryInfo? battery;
  final StorageInfo? storage;
  final bool? developerMode;
  final String? basebandVersion;
  final String? wifiAddress;

  /// Raw errors / missing domains, for the technical section.
  final List<String> notes;
  final DateTime? readAt;

  static const empty = DeviceFacts();
}
