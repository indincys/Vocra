import Foundation
import OSLog
import ServiceManagement

private let launchAtLoginLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "LaunchAtLogin"
)

/// Registers the app as a login item so it comes back automatically after a reboot.
public protocol LaunchAtLoginManaging: Sendable {
  var isEnabled: Bool { get }
  /// True when macOS knows about the login item but the user has switched it off in
  /// System Settings › General › Login Items — the app can't re-enable it programmatically.
  var isBlockedBySystemSettings: Bool { get }
  func setEnabled(_ enabled: Bool) throws
}

/// `SMAppService.mainApp`-backed implementation. macOS relaunches the whole app bundle at
/// login; because the main window scene declares `.defaultLaunchBehavior(.suppressed)` and
/// `AppDelegate` detects a non-default launch, that relaunch stays in the background with
/// only the menu-bar item.
public struct LaunchAtLoginService: LaunchAtLoginManaging {
  public init() {}

  public var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  public var isBlockedBySystemSettings: Bool {
    SMAppService.mainApp.status == .requiresApproval
  }

  public func setEnabled(_ enabled: Bool) throws {
    if enabled {
      // Registering an already-registered service throws; treat "already on" as success.
      guard SMAppService.mainApp.status != .enabled else { return }
      try SMAppService.mainApp.register()
      launchAtLoginLogger.info("Registered Vocra as a login item.")
    } else {
      guard SMAppService.mainApp.status != .notRegistered else { return }
      try SMAppService.mainApp.unregister()
      launchAtLoginLogger.info("Unregistered Vocra as a login item.")
    }
  }
}

/// In-memory stand-in for tests and previews; never touches the real login-item database.
public final class InMemoryLaunchAtLoginService: LaunchAtLoginManaging, @unchecked Sendable {
  private let lock = NSLock()
  private var enabled: Bool

  public init(enabled: Bool = false) {
    self.enabled = enabled
  }

  public var isEnabled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return enabled
  }

  public var isBlockedBySystemSettings: Bool { false }

  public func setEnabled(_ enabled: Bool) throws {
    lock.lock()
    self.enabled = enabled
    lock.unlock()
  }
}
