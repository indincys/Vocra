import XCTest
@testable import Vocra

final class SettingsViewTests: XCTestCase {
  func testAPIConnectionStatusUsesExpectedIcons() {
    XCTAssertNil(APIConnectionTestStatus.idle.systemImageName)
    XCTAssertEqual(APIConnectionTestStatus.testing.systemImageName, "arrow.triangle.2.circlepath")
    XCTAssertEqual(APIConnectionTestStatus.succeeded.systemImageName, "checkmark.circle.fill")
    XCTAssertEqual(APIConnectionTestStatus.failed.systemImageName, "xmark.octagon.fill")
  }
}
