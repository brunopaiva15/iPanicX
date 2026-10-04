import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// Native macOS services used by the Dart side (`lib/services/macos_bridge.dart`).
///
/// Channel: `ipanix/bridge`
///  - `saveTextFile` {suggestedName, contents} -> String? (saved path)
///  - `pickIpsFile` -> String? (chosen path)
///  - `revealInFinder` {path} -> Bool
///  - `bundledToolsPath` -> String? (libimobiledevice inside the app bundle)
final class IPhoneBridge: NSObject {
  static let channelName = "ipanix/bridge"

  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?

  init(messenger: FlutterBinaryMessenger, window: NSWindow?) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.window = window
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "saveTextFile":
      saveTextFile(
        suggestedName: args["suggestedName"] as? String ?? "iPaniX-report.txt",
        contents: args["contents"] as? String ?? "",
        result: result)
    case "pickIpsFile":
      pickIpsFile(result: result)
    case "revealInFinder":
      guard let path = args["path"] as? String,
        FileManager.default.fileExists(atPath: path)
      else {
        result(false)
        return
      }
      NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
      result(true)
    case "bundledToolsPath":
      result(Bundle.main.resourceURL?.appendingPathComponent("libimobiledevice/bin").path)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func saveTextFile(suggestedName: String, contents: String, result: @escaping FlutterResult) {
    let panel = NSSavePanel()
    panel.title = "Export Report"
    panel.nameFieldStringValue = suggestedName
    panel.canCreateDirectories = true
    panel.allowedContentTypes = [.plainText]

    let completion: (NSApplication.ModalResponse) -> Void = { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      do {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        result(url.path)
      } catch {
        result(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil))
      }
    }
    present(panel, completion: completion)
  }

  private func pickIpsFile(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.title = "Open Panic Report"
    panel.message = "Choose a panic-full .ips file to analyze locally."
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    // .ips files have no system UTType; leave every file selectable.

    present(panel) { response in
      result(response == .OK ? panel.url?.path : nil)
    }
  }

  private func present(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
    if let window {
      panel.beginSheetModal(for: window, completionHandler: completion)
    } else {
      completion(panel.runModal())
    }
  }
}
