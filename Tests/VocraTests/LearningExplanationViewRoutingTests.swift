import SwiftUI
import XCTest
@testable import Vocra
import VocraCore

@MainActor
final class LearningExplanationViewRoutingTests: XCTestCase {
  func testPanelRendersSentenceLearningDocument() {
    let view = ExplanationPanelView(
      capturedText: CapturedText(
        originalText: "She studies because she wants to improve.",
        cleanedText: "She studies because she wants to improve.",
        mode: .sentence,
        sourceApp: "Tests"
      ),
      document: sentenceDocument(),
      errorMessage: nil,
      validationErrorMessage: nil,
      onSwitchMode: { _ in },
      onClose: {}
    )

    XCTAssertNotNil(view.body)
  }

  func testRouterRendersWordLearningDocument() {
    let view = LearningExplanationView(document: wordDocument())

    XCTAssertNotNil(view.body)
  }

  func testRouterRendersVocabularyCardWhenPrimaryBranchIsMissing() {
    let view = LearningExplanationView(document: vocabularyCardDocument())

    XCTAssertNotNil(view.body)
  }
}

private func sentenceDocument() -> LearningExplanationDocument {
  LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: .sentence,
    sourceText: "She studies because she wants to improve.",
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: SentenceAnalysis(
      headline: LearningHeadline(title: "Cause and purpose", subtitle: "A sentence with motivation"),
      sentence: AnalyzedSentence(
        text: "She studies because she wants to improve.",
        segments: [
          SentenceSegment(id: "main", text: "She studies", role: "mainClause", labelZh: "主句", labelEn: "Main clause", color: .blue),
          SentenceSegment(id: "reason", text: "because she wants to improve", role: "reasonClause", labelZh: "原因", labelEn: "Reason", color: .green)
        ]
      ),
      structureBreakdown: StructureBreakdown(
        title: "Structure",
        items: [
          StructureItem(
            id: "root",
            text: "She studies",
            role: "mainClause",
            labelZh: "主句",
            labelEn: "Main clause",
            children: [
              StructureItem(id: "child", text: "because she wants to improve", role: "reasonClause", labelZh: "原因", labelEn: "Reason", children: [])
            ]
          )
        ]
      ),
      relationshipDiagram: RelationshipDiagram(
        nodes: [
          RelationshipNode(id: "main", title: "Action", text: "She studies"),
          RelationshipNode(id: "reason", title: "Reason", text: "she wants to improve")
        ],
        edges: [
          RelationshipEdge(from: "reason", to: "main", labelZh: "解释原因", labelEn: "explains why")
        ]
      ),
      logicSummary: LogicSummary(
        title: "Logic",
        points: ["The second clause explains the reason for the first."],
        coreMeaning: "She studies with the goal of improving."
      ),
      translation: TranslationBlock(title: "Translation", text: "她学习，因为她想进步。"),
      keyVocabulary: [
        KeyVocabularyItem(term: "improve", meaning: "变得更好", note: "Used for progress or skill growth.")
      ]
    ),
    wordExplanation: nil,
    vocabularyCard: nil,
    warnings: []
  )
}

private func wordDocument() -> LearningExplanationDocument {
  LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: .word,
    sourceText: "improve",
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: nil,
    wordExplanation: WordExplanation(
      term: "improve",
      pronunciation: "/imˈpruːv/",
      partOfSpeech: "verb",
      coreMeaning: "to become better",
      contextualMeaning: "to make progress in study or ability",
      usageNotes: ["Often followed by a skill or result."],
      collocations: ["improve quickly", "improve your English"],
      examples: [
        LearningExample(sentence: "Her writing improved.", translation: "她的写作进步了。", note: "Intransitive use.")
      ],
      commonMistakes: ["Do not say 'improve better'."]
    ),
    vocabularyCard: nil,
    warnings: []
  )
}

private func vocabularyCardDocument() -> LearningExplanationDocument {
  LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: .phrase,
    sourceText: "context window",
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: nil,
    wordExplanation: nil,
    vocabularyCard: StructuredVocabularyCard(
      front: VocabularyCardFront(text: "context window", hint: "AI memory span"),
      back: VocabularyCardBack(
        coreMeaning: "上下文窗口",
        memoryNote: "context + window = the visible text range",
        usage: "Used when discussing how much text a model can consider."
      ),
      examples: [
        VocabularyCardExample(sentence: "The model has a larger context window.", translation: "这个模型有更大的上下文窗口。")
      ],
      reviewPrompts: ["What does context window mean?"]
    ),
    warnings: []
  )
}
