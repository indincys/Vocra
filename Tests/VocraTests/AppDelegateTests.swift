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
}
