import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var openMainWindow: (() -> Void)?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    openMainWindow?()
    return false
  }
}
