/// An iPhone detected over USB.
class IPhoneDevice {
  const IPhoneDevice({
    required this.udid,
    this.deviceName,
    this.productType,
    this.productVersion,
    this.buildVersion,
    this.hardwareModel,
    this.connection = 'USB',
    this.isPaired = true,
  });

  final String udid;
  final String? deviceName;

  /// Internal identifier, e.g. `iPhone15,2`.
  final String? productType;

  /// iOS version, e.g. `26.0`.
  final String? productVersion;

  /// iOS build, e.g. `23A341`.
  final String? buildVersion;

  /// Board identifier, e.g. `D73AP`.
  final String? hardwareModel;

  final String connection;

  /// False when only the unpaired subset of lockdown values could be read.
  final bool isPaired;

  /// Marketing name derived from [productType], e.g. `iPhone 14 Pro`.
  String get modelName =>
      marketingNameFor(productType) ?? productType ?? 'iPhone';

  /// Title shown in the UI: the device's own name if known, else the model.
  String get displayName =>
      (deviceName != null && deviceName!.trim().isNotEmpty)
      ? deviceName!
      : modelName;

  /// UDID with the middle part masked: `00008120-0012…3A4E`.
  String get maskedUdid => maskUdid(udid);

  static String maskUdid(String udid) {
    if (udid.length <= 10) return '•' * udid.length;
    return '${udid.substring(0, 6)}••••••${udid.substring(udid.length - 4)}';
  }

  IPhoneDevice copyWith({bool? isPaired}) => IPhoneDevice(
    udid: udid,
    deviceName: deviceName,
    productType: productType,
    productVersion: productVersion,
    buildVersion: buildVersion,
    hardwareModel: hardwareModel,
    connection: connection,
    isPaired: isPaired ?? this.isPaired,
  );

  @override
  bool operator ==(Object other) =>
      other is IPhoneDevice &&
      other.udid == udid &&
      other.deviceName == deviceName &&
      other.productType == productType &&
      other.productVersion == productVersion &&
      other.buildVersion == buildVersion &&
      other.isPaired == isPaired;

  @override
  int get hashCode => Object.hash(
    udid,
    deviceName,
    productType,
    productVersion,
    buildVersion,
    isPaired,
  );

  @override
  String toString() => 'IPhoneDevice($productType, iOS $productVersion)';
}

/// Small lookup table of iPhone product types. Unknown identifiers fall back
/// to the raw product type in the UI.
const Map<String, String> _marketingNames = {
  'iPhone10,1': 'iPhone 8',
  'iPhone10,4': 'iPhone 8',
  'iPhone10,2': 'iPhone 8 Plus',
  'iPhone10,5': 'iPhone 8 Plus',
  'iPhone10,3': 'iPhone X',
  'iPhone10,6': 'iPhone X',
  'iPhone11,2': 'iPhone XS',
  'iPhone11,4': 'iPhone XS Max',
  'iPhone11,6': 'iPhone XS Max',
  'iPhone11,8': 'iPhone XR',
  'iPhone12,1': 'iPhone 11',
  'iPhone12,3': 'iPhone 11 Pro',
  'iPhone12,5': 'iPhone 11 Pro Max',
  'iPhone12,8': 'iPhone SE (2nd generation)',
  'iPhone13,1': 'iPhone 12 mini',
  'iPhone13,2': 'iPhone 12',
  'iPhone13,3': 'iPhone 12 Pro',
  'iPhone13,4': 'iPhone 12 Pro Max',
  'iPhone14,4': 'iPhone 13 mini',
  'iPhone14,5': 'iPhone 13',
  'iPhone14,2': 'iPhone 13 Pro',
  'iPhone14,3': 'iPhone 13 Pro Max',
  'iPhone14,6': 'iPhone SE (3rd generation)',
  'iPhone14,7': 'iPhone 14',
  'iPhone14,8': 'iPhone 14 Plus',
  'iPhone15,2': 'iPhone 14 Pro',
  'iPhone15,3': 'iPhone 14 Pro Max',
  'iPhone15,4': 'iPhone 15',
  'iPhone15,5': 'iPhone 15 Plus',
  'iPhone16,1': 'iPhone 15 Pro',
  'iPhone16,2': 'iPhone 15 Pro Max',
  'iPhone17,3': 'iPhone 16',
  'iPhone17,4': 'iPhone 16 Plus',
  'iPhone17,1': 'iPhone 16 Pro',
  'iPhone17,2': 'iPhone 16 Pro Max',
  'iPhone17,5': 'iPhone 16e',
  'iPhone18,3': 'iPhone 17',
  'iPhone18,1': 'iPhone 17 Pro',
  'iPhone18,2': 'iPhone 17 Pro Max',
  'iPhone18,4': 'iPhone Air',
};

String? marketingNameFor(String? productType) =>
    productType == null ? null : _marketingNames[productType];
