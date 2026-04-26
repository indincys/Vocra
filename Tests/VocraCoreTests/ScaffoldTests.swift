import XCTest
@testable import VocraCore

final class ScaffoldTests: XCTestCase {
  func testExplanationModeDisplayNames() {
    XCTAssertEqual(ExplanationMode.word.displayName, "Word")
    XCTAssertEqual(ExplanationMode.phrase.displayName, "Term")
    XCTAssertEqual(ExplanationMode.sentence.displayName, "Sentence")
  }
}
