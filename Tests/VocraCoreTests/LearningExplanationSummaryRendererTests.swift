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
}
