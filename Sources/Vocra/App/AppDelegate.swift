import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var openMainWindow: (() -> Void)?
  /// True when this process was started by the login item (or any other non-user launch)
  /// rather than by the user double-clicking the app.
  private(set) var launchedInBackground = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    // macOS reports a login-item / auto-relaunch start as a non-default launch. In that case
    // stay a menu-bar-only accessory: no Dock icon, no window, nothing stealing focus from
    // whatever the user is actually doing right after login. The policy is promoted to
    // `.regular` the first time the main window is opened.
    let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
    launchedInBackground = !isDefaultLaunch
    NSApp.setActivationPolicy(isDefaultLaunch ? .regular : .accessory)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    presentMainWindow()
    return false
  }

  /// Brings the main window up, promoting a background (accessory) launch to a full app with
  /// a Dock icon first so the window can take key focus.
  func presentMainWindow() {
    if NSApp.activationPolicy() != .regular {
      NSApp.setActivationPolicy(.regular)
    }
    openMainWindow?()
  }
}
