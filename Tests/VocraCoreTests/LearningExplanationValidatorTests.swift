import XCTest
@testable import VocraCore

final class LearningExplanationValidatorTests: XCTestCase {
  func testRejectsModeMismatch() throws {
    let document = validSentenceDocument()

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .word, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .modeMismatch(expected: .word, actual: .sentence))
    }
  }

  func testRejectsMissingActiveBranch() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis = nil

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .missingBranch("sentenceAnalysis"))
    }
  }

  func testRejectsDuplicateSegmentIDs() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis?.sentence.segments = [
      SentenceSegment(id: "dup", text: "Codex", role: "subject", labelZh: "主语", labelEn: "Subject", color: .blue),
      SentenceSegment(id: "dup", text: "works best", role: "predicate", labelZh: "谓语", labelEn: "Predicate", color: .green)
    ]

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .duplicateID("sentence.segments", "dup"))
    }
  }

  func testAcceptsWhitespaceNormalizedSourceText() throws {
    let document = validSentenceDocument()

    XCTAssertNoThrow(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: " Codex   works best. "))
  }

  private func validSentenceDocument() -> LearningExplanationDocument {
    LearningExplanationDocument(
      schemaVersion: 1,
      mode: .sentence,
      sourceText: "Codex works best.",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: SentenceAnalysis(
        headline: LearningHeadline(title: "例句解析", subtitle: "Sentence Analysis"),
        sentence: AnalyzedSentence(
          text: "Codex works best.",
          segments: [
            SentenceSegment(id: "s1", text: "Codex", role: "subject", labelZh: "主语", labelEn: "Subject", color: .blue)
          ]
        ),
        structureBreakdown: StructureBreakdown(title: "结构解析", items: []),
        relationshipDiagram: RelationshipDiagram(nodes: [], edges: []),
        logicSummary: LogicSummary(title: "核心含义", points: ["Codex 是主语。"], coreMeaning: "Codex 效果最好。"),
        translation: TranslationBlock(title: "例句翻译", text: "Codex 效果最好。"),
        keyVocabulary: []
      ),
      wordExplanation: nil,
      vocabularyCard: nil,
      warnings: []
    )
  }
}
