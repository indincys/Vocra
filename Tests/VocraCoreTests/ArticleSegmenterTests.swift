import XCTest
@testable import VocraCore

final class ArticleSegmenterTests: XCTestCase {
  private let segmenter = ArticleSegmenter()

  func testSplitsParagraphIntoSentences() {
    let draft = segmenter.segment("The model failed. It returned an empty body. We retried once.")

    XCTAssertEqual(draft.sentences.count, 3)
    XCTAssertEqual(draft.sentences.map(\.text), [
      "The model failed.",
      "It returned an empty body.",
      "We retried once."
    ])
    XCTAssertEqual(draft.sentences.map(\.paragraphIndex), [0, 0, 0])
  }

  func testBlankLinesSeparateParagraphs() {
    let draft = segmenter.segment("First paragraph here.\n\nSecond paragraph here.")

    XCTAssertEqual(draft.paragraphCount, 2)
    XCTAssertEqual(draft.sentences.map(\.paragraphIndex), [0, 1])
  }

  func testSoftWrappedLinesAreRejoinedIntoOneSentence() {
    let draft = segmenter.segment("The request timed out\nbecause the endpoint was slow.")

    XCTAssertEqual(draft.sentences.count, 1)
    XCTAssertEqual(draft.sentences.first?.text, "The request timed out because the endpoint was slow.")
  }

  func testHealsHyphenationAcrossALineBreak() {
    let draft = segmenter.segment("The system stores informa-\ntion locally.")

    XCTAssertEqual(draft.sentences.first?.text, "The system stores information locally.")
  }

  func testUsesShortOpeningLineAsTitle() {
    let draft = segmenter.segment("Why Streaming Matters\n\nStreaming keeps the idle timeout from firing.")

    XCTAssertEqual(draft.title, "Why Streaming Matters")
  }

  func testFallsBackToTruncatedFirstSentenceForTitle() {
    let text = "Streaming keeps the request's idle timeout from firing during a long single-shot generation."
    let draft = segmenter.segment(text)

    XCTAssertTrue(draft.title.hasSuffix("…"))
    XCTAssertTrue(text.hasPrefix(draft.title.dropLast()))
  }

  func testShortSelectionIsNotCollectable() {
    let draft = segmenter.segment("Too short.")

    XCTAssertFalse(ArticleLengthPolicy.isCollectable(draft))
  }

  func testParagraphIsCollectableButNotNecessarilyLongForm() {
    let draft = segmenter.segment("The endpoint returned a malformed body, so the client retried the request once.")

    XCTAssertTrue(ArticleLengthPolicy.isCollectable(draft))
    XCTAssertFalse(ArticleLengthPolicy.isLongForm(draft))
  }

  func testMultiSentenceArticleIsLongForm() {
    let paragraph = String(
      repeating: "The client streams the response so the idle timeout never fires mid-generation. ",
      count: 4
    )
    let draft = segmenter.segment(paragraph)

    XCTAssertTrue(ArticleLengthPolicy.isLongForm(draft))
  }

  func testEmptySelectionProducesNoSentences() {
    XCTAssertTrue(segmenter.segment("   \n\n  ").isEmpty)
  }
}
