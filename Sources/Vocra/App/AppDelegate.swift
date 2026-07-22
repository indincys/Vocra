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

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillClose(_:)),
      name: NSWindow.willCloseNotification,
      object: nil
    )
  }

  /// Vocra lives in the menu bar, so closing its window must never take the process — and
  /// with it the global shortcuts — down.
  ///
  /// SwiftUI's default for an app that owns a `Window`/`WindowGroup` scene is to terminate
  /// once the last window closes, and that default applies whenever the app's own delegate
  /// doesn't answer this. That is exactly what users saw as "the app quits by itself": the
  /// system log recorded a `voluntary` exit(0) a few milliseconds after the WindowServer
  /// assertions for the closing window were invalidated. Returning `false` keeps the menu
  /// bar item (and `ShortcutService`'s Carbon hot keys) alive after the window is closed.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
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

  /// Drops back to menu-bar-only once the last real window goes away, so a closed window
  /// doesn't leave an app with a Dock icon and nothing behind it. Runs on the next runloop
  /// turn because the closing window is still listed in `NSApp.windows` during the
  /// notification.
  @objc private func windowWillClose(_ notification: Notification) {
    guard NSApp.activationPolicy() == .regular else { return }
    let closing = notification.object as? NSWindow
    DispatchQueue.main.async {
      let hasVisibleWindow = NSApp.windows.contains { window in
        window !== closing && window.isVisible && window.canBecomeMain
      }
      guard !hasVisibleWindow else { return }
      NSApp.setActivationPolicy(.accessory)
    }
  }
}
