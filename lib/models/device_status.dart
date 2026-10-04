import 'iphone_device.dart';

enum DeviceConnectionState {
  /// First lookup has not finished yet.
  searching,
  noDevice,
  connected,

  /// Device is attached but the Mac is not (yet) trusted.
  trustRequired,

  /// Device is attached but locked (passcode required before first unlock /
  /// pairing).
  locked,

  /// Device is attached but lockdown/usbmuxd returned an error.
  communicationError,

  /// libimobiledevice executables could not be found.
  toolsUnavailable,
}

/// Snapshot of what the service currently knows about the USB connection.
class DeviceStatus {
  const DeviceStatus({
    required this.state,
    this.device,
    this.udid,
    this.deviceCount = 0,
    this.message,
    this.technicalDetails,
  });

  const DeviceStatus.searching() : this(state: DeviceConnectionState.searching);

  const DeviceStatus.noDevice() : this(state: DeviceConnectionState.noDevice);

  final DeviceConnectionState state;

  /// Device info. Can be partially filled for [trustRequired] (unpaired
  /// values only).
  final IPhoneDevice? device;

  /// UDID of the selected device, even when its info could not be read.
  final String? udid;

  /// Number of devices seen by `idevice_id`.
  final int deviceCount;

  /// Short user-facing explanation.
  final String? message;

  /// Raw tool output, shown only in the optional technical section.
  final String? technicalDetails;

  bool get isConnected => state == DeviceConnectionState.connected;
  bool get hasMultipleDevices => deviceCount > 1;

  @override
  bool operator ==(Object other) =>
      other is DeviceStatus &&
      other.state == state &&
      other.device == device &&
      other.udid == udid &&
      other.deviceCount == deviceCount &&
      other.message == message &&
      other.technicalDetails == technicalDetails;

  @override
  int get hashCode =>
      Object.hash(state, device, udid, deviceCount, message, technicalDetails);
}
