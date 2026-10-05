import 'iphone_device.dart';

enum DeviceConnectionState {
  /// First lookup has not finished yet.
  searching,
  noDevice,

  /// The OS sees an iPhone on USB but usbmuxd / Apple Mobile Device Service
  /// does not list it (driver missing, service stuck, USB restricted mode).
  notRecognized,
  connected,

  /// Device is attached but this computer is not (yet) trusted.
  trustRequired,

  /// Device is attached but locked (passcode required before first unlock /
  /// pairing).
  locked,

  /// Device is attached but lockdown/usbmuxd returned an error.
  communicationError,

  /// libimobiledevice executables could not be found.
  toolsUnavailable,
}

/// Why a non-connected state was reached, when the state alone is not
/// enough to word the explanation.
enum StatusReason {
  /// The user tapped "Don't Trust".
  pairingDenied,

  /// The device did not answer in time.
  timeout,

  /// usbmuxd / Apple Mobile Device Service could not be reached.
  usbServiceUnavailable,

  /// Windows lists the iPhone with a device-manager error.
  driverProblem,
}

/// Snapshot of what the service currently knows about the USB connection.
class DeviceStatus {
  const DeviceStatus({
    required this.state,
    this.device,
    this.udid,
    this.deviceCount = 0,
    this.message,
    this.reason,
    this.technicalDetails,
  });

  const DeviceStatus.searching() : this(state: DeviceConnectionState.searching);

  const DeviceStatus.noDevice({String? technicalDetails})
    : this(
        state: DeviceConnectionState.noDevice,
        technicalDetails: technicalDetails,
      );

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

  final StatusReason? reason;

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
      other.reason == reason &&
      other.technicalDetails == technicalDetails;

  @override
  int get hashCode => Object.hash(
    state,
    device,
    udid,
    deviceCount,
    message,
    reason,
    technicalDetails,
  );
}
