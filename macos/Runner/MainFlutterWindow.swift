import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var iphoneBridge: IPhoneBridge?
  private var deviceWatcher: DeviceWatcher?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.title = "iPanicX"
    self.contentMinSize = NSSize(width: 900, height: 600)
    self.setContentSize(NSSize(width: 1120, height: 780))
    self.center()
    self.setFrameAutosaveName("iPanicXMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger
    iphoneBridge = IPhoneBridge(messenger: messenger, window: self)
    deviceWatcher = DeviceWatcher(messenger: messenger)

    super.awakeFromNib()
  }
}
