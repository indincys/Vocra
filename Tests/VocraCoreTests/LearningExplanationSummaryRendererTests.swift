import XCTest
@testable import VocraCore

final class LearningExplanationSummaryRendererTests: XCTestCase {
  func testRendersSentencePlainTextSummary() {
    let document = LearningExplanationDocument(
      schemaVersion: 1,
      mode: .sentence,
      sourceText: "Codex works best.",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: SentenceAnalysis(
        headline: LearningHeadline(title: "例句解析", subtitle: "Sentence Analysis"),
        sentence: AnalyzedSentence(text: "Codex works best.", segments: []),
        structureBreakdown: StructureBreakdown(title: "结构解析", items: []),
        relationshipDiagram: RelationshipDiagram(nodes: [], edges: []),
        logicSummary: LogicSummary(title: "核心含义", points: ["主干是 Codex works best."], coreMeaning: "Codex 效果最好。"),
        translation: TranslationBlock(title: "例句翻译", text: "Codex 效果最好。"),
        keyVocabulary: []
      ),
      wordExplanation: nil,
      vocabularyCard: nil,
      warnings: []
    )

    let summary = LearningExplanationSummaryRenderer().render(document)

    XCTAssertTrue(summary.contains("Codex works best."))
    XCTAssertTrue(summary.contains("Codex 效果最好。"))
  }

  func testRendersVocabularyCardPlainTextSummaryBeforeModeFallback() {
    let document = LearningExplanationDocument(
      schemaVersion: 1,
      mode: .word,
      sourceText: "serendipity",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: nil,
      vocabularyCard: StructuredVocabularyCard(
        front: VocabularyCardFront(text: "serendipity", hint: "unexpected good luck"),
        back: VocabularyCardBack(
          coreMeaning: "意外发现美好事物的能力或好运。",
          memoryNote: "Think of finding something valuable by chance.",
          usage: "Use it for pleasant accidental discoveries."
        ),
        examples: [
          VocabularyCardExample(sentence: "Finding that cafe was pure serendipity.", translation: "发现那家咖啡馆纯属意外之喜。")
        ],
        reviewPrompts: [
          "Use serendipity in a sentence."
        ]
      ),
      warnings: []
    )

    let summary = LearningExplanationSummaryRenderer().render(document)

    XCTAssertTrue(summary.contains("serendipity"))
    XCTAssertTrue(summary.contains("意外发现美好事物的能力或好运。"))
    XCTAssertTrue(summary.contains("Think of finding something valuable by chance."))
    XCTAssertTrue(summary.contains("Finding that cafe was pure serendipity."))
  }

  func testPrefersWordExplanationWhenVocabularyCardIsAlsoPresent() {
    let document = LearningExplanationDocument(
      schemaVersion: 1,
      mode: .word,
      sourceText: "serendipity",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: WordExplanation(
        term: "serendipity",
        pronunciation: nil,
        partOfSpeech: "noun",
        coreMeaning: "A lucky accidental discovery.",
        contextualMeaning: "Finding something good without planning.",
        usageNotes: ["Usually positive and slightly literary."],
        collocations: [],
        examples: [],
        commonMistakes: []
      ),
      vocabularyCard: StructuredVocabularyCard(
        front: VocabularyCardFront(text: "serendipity", hint: nil),
        back: VocabularyCardBack(
          coreMeaning: "Card-only meaning",
          memoryNote: "Card-only memory note",
          usage: "Card-only usage"
        ),
        examples: [
          VocabularyCardExample(sentence: "Card-only example sentence.", translation: "卡片专用例句。")
        ],
        reviewPrompts: []
      ),
      warnings: []
    )

    let summary = LearningExplanationSummaryRenderer().render(document)

    XCTAssertTrue(summary.contains("A lucky accidental discovery."))
    XCTAssertTrue(summary.contains("Finding something good without planning."))
    XCTAssertFalse(summary.contains("Card-only memory note"))
    XCTAssertFalse(summary.contains("Card-only example sentence."))
  }
}
