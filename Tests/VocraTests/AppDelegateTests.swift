import AppKit
import XCTest
@testable import Vocra

@MainActor
final class AppDelegateTests: XCTestCase {
  func testDockReopenRequestsMainWindow() {
    let delegate = AppDelegate()
    var didRequestMainWindow = false
    delegate.openMainWindow = {
      didRequestMainWindow = true
    }

    let shouldContinueDefaultHandling = delegate.applicationShouldHandleReopen(
      NSApplication.shared,
      hasVisibleWindows: false
    )

    XCTAssertTrue(didRequestMainWindow)
    XCTAssertFalse(shouldContinueDefaultHandling)
  }

  /// Regression: closing the main window used to terminate the process (a `voluntary`
  /// exit(0) in the system log), taking the menu bar item and the global shortcuts with it.
  func testClosingLastWindowDoesNotTerminateTheApp() {
    let delegate = AppDelegate()

    XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
  }
}
