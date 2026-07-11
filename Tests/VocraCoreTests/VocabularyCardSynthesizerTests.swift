import XCTest
@testable import VocraCore

final class VocabularyCardSynthesizerTests: XCTestCase {
  func testMapsWordExplanationFieldsIntoCard() throws {
    let captured = CapturedText(originalText: "resolve", cleanedText: "resolve", mode: .word, sourceApp: nil)
    let document = wordDocument(
      term: "resolve",
      partOfSpeech: "verb",
      coreMeaning: "解决；决心",
      contextualMeaning: "在这里指彻底处理掉问题",
      usageNotes: ["常接 issue / conflict / dispute。", "正式语体。"],
      collocations: ["resolve a dispute"],
      examples: [
        LearningExample(sentence: "They resolved the issue.", translation: "他们解决了这个问题。", note: "note ignored")
      ]
    )

    let card = try XCTUnwrap(VocabularyCardSynthesizer.card(from: document, captured: captured)?.vocabularyCard)

    XCTAssertEqual(card.front.text, "resolve")
    XCTAssertEqual(card.front.hint, "verb")
    XCTAssertEqual(card.back.coreMeaning, "解决；决心")
    XCTAssertEqual(card.back.memoryNote, "在这里指彻底处理掉问题")
    XCTAssertEqual(card.back.usage, "常接 issue / conflict / dispute。\n正式语体。")
    XCTAssertEqual(card.examples, [VocabularyCardExample(sentence: "They resolved the issue.", translation: "他们解决了这个问题。")])
  }

  func testFallsBackWhenOptionalFieldsAreEmpty() throws {
    let captured = CapturedText(originalText: "resolve", cleanedText: "resolve", mode: .word, sourceApp: nil)
    let document = wordDocument(
      term: "",
      partOfSpeech: "",
      coreMeaning: "解决",
      contextualMeaning: "",
      usageNotes: [],
      collocations: [],
      examples: [LearningExample(sentence: " ", translation: "", note: nil)]
    )

    let card = try XCTUnwrap(VocabularyCardSynthesizer.card(from: document, captured: captured)?.vocabularyCard)

    XCTAssertEqual(card.front.text, "resolve", "falls back to the captured text when term is empty")
    XCTAssertNil(card.front.hint)
    XCTAssertEqual(card.back.coreMeaning, "解决")
    // memoryNote / usage fall back to the core meaning when contextual meaning and notes are empty.
    XCTAssertEqual(card.back.memoryNote, "解决")
    XCTAssertEqual(card.back.usage, "解决")
    XCTAssertTrue(card.examples.isEmpty, "blank examples are dropped")
  }

  func testReturnsNilWithoutWordExplanation() {
    let captured = CapturedText(originalText: "Codex works best.", cleanedText: "Codex works best.", mode: .sentence, sourceApp: nil)
    let document = LearningExplanationDocument(
      schemaVersion: 1,
      mode: .sentence,
      sourceText: "Codex works best.",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: nil,
      vocabularyCard: nil,
      warnings: []
    )

    XCTAssertNil(VocabularyCardSynthesizer.card(from: document, captured: captured))
  }

  private func wordDocument(
    term: String,
    partOfSpeech: String,
    coreMeaning: String,
    contextualMeaning: String,
    usageNotes: [String],
    collocations: [String],
    examples: [LearningExample]
  ) -> LearningExplanationDocument {
    LearningExplanationDocument(
      schemaVersion: 1,
      mode: .word,
      sourceText: term,
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: WordExplanation(
        term: term,
        pronunciation: nil,
        partOfSpeech: partOfSpeech,
        coreMeaning: coreMeaning,
        contextualMeaning: contextualMeaning,
        usageNotes: usageNotes,
        collocations: collocations,
        examples: examples,
        commonMistakes: []
      ),
      vocabularyCard: nil,
      warnings: []
    )
  }
}
