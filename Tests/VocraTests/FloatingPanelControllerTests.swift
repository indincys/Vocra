import AppKit
import SwiftUI
import XCTest
@testable import Vocra

@MainActor
final class FloatingPanelControllerTests: XCTestCase {
  func testEscapeClosingPanelInvokesEscapeHandlerForCancelOperation() {
    let panel = EscapeClosingPanel(
      contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    var didClose = false
    panel.onEscape = {
      didClose = true
    }

    panel.cancelOperation(nil)

    XCTAssertTrue(didClose)
  }

}
