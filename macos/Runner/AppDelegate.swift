import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var pendingFiles: [String] = []
  private var launchChannel: FlutterMethodChannel?
  private var launchReady = false

  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "visor-config/launch", binaryMessenger: controller.engine.binaryMessenger)
    launchChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.launchReady = true
      self?.deliverPendingFiles()
      result(nil)
    }
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let otherURLs = urls.filter { !$0.isFileURL }
    if !otherURLs.isEmpty {
      super.application(application, open: otherURLs)
    }
    pendingFiles.append(contentsOf: urls.filter { $0.isFileURL }.map { $0.path })
    deliverPendingFiles()
  }

  private func deliverPendingFiles() {
    guard launchReady, !pendingFiles.isEmpty else { return }
    launchChannel?.invokeMethod("open", arguments: ["arguments": ["--"] + pendingFiles])
    pendingFiles.removeAll()
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
