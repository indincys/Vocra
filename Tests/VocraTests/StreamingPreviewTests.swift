import XCTest
@testable import Vocra

final class StreamingPreviewTests: XCTestCase {
  func testKeepsStringValuesAndSkipsKeys() {
    let raw = #"{"mode":"word","wordExplanation":{"coreMeaning":"幂等的，重复执行结果一致"#
    let preview = extractStreamingPreview(from: raw, maxLength: 80)

    XCTAssertTrue(preview.contains("幂等的"))
    XCTAssertFalse(preview.contains("coreMeaning")) // key is skipped
    XCTAssertFalse(preview.contains("wordExplanation"))
  }

  func testTruncatesToTailWithLeadingEllipsis() {
    let longValue = String(repeating: "讲", count: 200)
    let raw = "{\"k\":\"\(longValue)\""
    let preview = extractStreamingPreview(from: raw, maxLength: 40)

    XCTAssertTrue(preview.hasPrefix("…"))
    XCTAssertEqual(preview.count, 41) // ellipsis + 40 chars
  }

  func testEmptyForStructureOnly() {
    XCTAssertEqual(extractStreamingPreview(from: "{ } [ ] : ,"), "")
  }
}
