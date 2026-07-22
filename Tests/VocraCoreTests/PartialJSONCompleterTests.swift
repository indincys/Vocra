import XCTest
@testable import VocraCore

final class PartialJSONCompleterTests: XCTestCase {
  func testReturnsNilBeforeAnyStructureCloses() {
    XCTAssertNil(PartialJSONCompleter.completedObject(from: #"{ "sentenceAnalysis": { "translation": { "text": "配置好时"#))
  }

  func testClosesAfterFirstCompletedNestedObject() throws {
    let partial = #"{ "sentenceAnalysis": { "translation": { "text": "配置好时效果最好。" }, "sentence": { "segm"#
    let completed = try XCTUnwrap(PartialJSONCompleter.completedObject(from: partial))

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(completed.utf8))
    XCTAssertEqual(document.sentenceAnalysis?.translation.text, "配置好时效果最好。")
    XCTAssertEqual(document.sentenceAnalysis?.sentence.segments, [])
  }

  func testClosesAfterPartialSegmentArray() throws {
    let partial = """
    { "sentenceAnalysis": { "translation": { "text": "T" }, "sentence": { "segments": [ \
    { "id": "s1", "text": "Codex", "labelZh": "主语", "color": "blue", "note": "n" }, \
    { "id": "s2", "text": "wor
    """
    let completed = try XCTUnwrap(PartialJSONCompleter.completedObject(from: partial))

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(completed.utf8))
    let segments = try XCTUnwrap(document.sentenceAnalysis?.sentence.segments)
    // The second, half-written segment is dropped; the first complete one survives.
    XCTAssertEqual(segments.count, 1)
    XCTAssertEqual(segments.first?.text, "Codex")
  }

  func testIgnoresBracesInsideStrings() throws {
    let partial = #"{ "sentenceAnalysis": { "translation": { "text": "a } b ] c" }"#
    let completed = try XCTUnwrap(PartialJSONCompleter.completedObject(from: partial))

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(completed.utf8))
    XCTAssertEqual(document.sentenceAnalysis?.translation.text, "a } b ] c")
  }

  func testCompletesFullObjectUnchangedEnough() throws {
    let full = #"{ "sentenceAnalysis": { "translation": { "text": "done" } } }"#
    let completed = try XCTUnwrap(PartialJSONCompleter.completedObject(from: full))

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(completed.utf8))
    XCTAssertEqual(document.sentenceAnalysis?.translation.text, "done")
  }
}
