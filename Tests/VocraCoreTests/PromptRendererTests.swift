import XCTest
@testable import VocraCore

final class PromptRendererTests: XCTestCase {
  func testRendersSupportedVariables() throws {
    let template = PromptTemplate(kind: .sentenceExplanation, body: "Explain {{text}} from {{sourceApp}} as {{type}}.")
    let context = PromptContext(text: "The model returns JSON.", type: .sentence, sourceApp: "Safari", surroundingContext: "", createdAt: "2026-04-26T00:00:00Z")

    let output = try PromptRenderer().render(template, context: context)

    XCTAssertEqual(output, "Explain The model returns JSON. from Safari as sentence.")
  }

  func testRejectsUnknownVariables() {
    let template = PromptTemplate(kind: .wordExplanation, body: "Explain {{unknown}}.")
    let context = PromptContext(text: "embedding", type: .word, sourceApp: nil, surroundingContext: "", createdAt: "2026-04-26T00:00:00Z")

    XCTAssertThrowsError(try PromptRenderer().render(template, context: context)) { error in
      XCTAssertEqual(error as? PromptRenderError, .unknownVariable("unknown"))
    }
  }

  func testDefaultStoreContainsFourPrompts() {
    let store = InMemoryPromptStore.defaults()
    XCTAssertNotNil(store.template(for: .wordExplanation))
    XCTAssertNotNil(store.template(for: .phraseExplanation))
    XCTAssertNotNil(store.template(for: .sentenceExplanation))
    XCTAssertNotNil(store.template(for: .vocabularyCard))
  }
}
