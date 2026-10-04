import Foundation
import FlutterMacOS
import IOKit
import IOKit.usb

/// Emits an event on `ipanix/usb_events` whenever an Apple USB device is
/// attached or detached, so the Dart side re-queries libimobiledevice
/// immediately instead of waiting for its next poll.
///
/// Event payload: `{"event": "attached" | "detached"}`.
final class DeviceWatcher: NSObject, FlutterStreamHandler {
  static let channelName = "ipanix/usb_events"
  private static let appleVendorId = 0x05AC

  private let channel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var notifyPort: IONotificationPortRef?
  private var addedIterator: io_iterator_t = 0
  private var removedIterator: io_iterator_t = 0

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterEventChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setStreamHandler(self)
  }

  deinit {
    stop()
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    start()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    eventSink = nil
    return nil
  }

  // MARK: IOKit

  private func matchingDictionary() -> CFMutableDictionary {
    let dict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
    dict.setObject(NSNumber(value: Self.appleVendorId), forKey: kUSBVendorID as NSString)
    return dict as CFMutableDictionary
  }

  private func start() {
    guard notifyPort == nil else { return }
    guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
    notifyPort = port
    let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)

    let context = Unmanaged.passUnretained(self).toOpaque()

    let onAdded: IOServiceMatchingCallback = { refcon, iterator in
      guard let refcon else { return }
      Unmanaged<DeviceWatcher>.fromOpaque(refcon).takeUnretainedValue()
        .drain(iterator, event: "attached")
    }
    let onRemoved: IOServiceMatchingCallback = { refcon, iterator in
      guard let refcon else { return }
      Unmanaged<DeviceWatcher>.fromOpaque(refcon).takeUnretainedValue()
        .drain(iterator, event: "detached")
    }

    IOServiceAddMatchingNotification(
      port, kIOFirstMatchNotification, matchingDictionary(), onAdded, context, &addedIterator)
    IOServiceAddMatchingNotification(
      port, kIOTerminatedNotification, matchingDictionary(), onRemoved, context, &removedIterator)

    // Iterators must be drained once to arm the notifications.
    drain(addedIterator, event: nil)
    drain(removedIterator, event: nil)
  }

  private func stop() {
    if addedIterator != 0 {
      IOObjectRelease(addedIterator)
      addedIterator = 0
    }
    if removedIterator != 0 {
      IOObjectRelease(removedIterator)
      removedIterator = 0
    }
    if let port = notifyPort {
      IONotificationPortDestroy(port)
      notifyPort = nil
    }
  }

  private func drain(_ iterator: io_iterator_t, event: String?) {
    var count = 0
    while case let service = IOIteratorNext(iterator), service != 0 {
      IOObjectRelease(service)
      count += 1
    }
    guard let event, count > 0 else { return }
    // libimobiledevice needs a moment before usbmuxd exposes the device.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
      self?.eventSink?(["event": event])
    }
  }
}
