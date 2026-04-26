import XCTest
@testable import VocraCore

final class TextClassifierTests: XCTestCase {
  private let classifier = TextClassifier()

  func testClassifiesSingleTokenAsWord() {
    XCTAssertEqual(classifier.classify("embedding").mode, .word)
  }

  func testClassifiesOneSpaceAsPhrase() {
    XCTAssertEqual(classifier.classify("context window").mode, .phrase)
  }

  func testClassifiesShortTechnicalTermWithTwoSpacesAsPhrase() {
    XCTAssertEqual(classifier.classify("retrieval augmented generation").mode, .phrase)
  }

  func testClassifiesPunctuatedSelectionAsSentence() {
    XCTAssertEqual(classifier.classify("The model failed to follow the instruction.").mode, .sentence)
  }

  func testClassifiesPredicateSelectionAsSentence() {
    XCTAssertEqual(classifier.classify("this function returns a string").mode, .sentence)
  }

  func testCollapsesWhitespaceBeforeClassifying() {
    let result = classifier.classify("  large   language   model  ")
    XCTAssertEqual(result.cleanedText, "large language model")
    XCTAssertEqual(result.mode, .phrase)
  }
}
