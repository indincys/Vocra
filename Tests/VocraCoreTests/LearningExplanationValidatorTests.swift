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

  func testRejectsEmptySentenceSegmentText() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis?.sentence.segments = [
      SentenceSegment(id: "s1", text: "Codex", role: "subject", labelZh: "主语", labelEn: "Subject", color: .blue),
      SentenceSegment(id: "s2", text: " ", role: "predicate", labelZh: "谓语", labelEn: "Predicate", color: .green)
    ]

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .emptyRequiredField("sentenceAnalysis.sentence.segments.s2.text"))
    }
  }

  func testRejectsMissingSentenceRequiredTextFields() throws {
    let cases: [(String, (inout LearningExplanationDocument) -> Void)] = [
      ("sentenceAnalysis.structureBreakdown.title", { $0.sentenceAnalysis?.structureBreakdown.title = " " }),
      ("sentenceAnalysis.relationshipDiagram.nodes.node1.title", {
        $0.sentenceAnalysis?.relationshipDiagram.nodes = [
          RelationshipNode(id: "node1", title: "", text: "Codex")
        ]
      }),
      ("sentenceAnalysis.relationshipDiagram.nodes.node1.text", {
        $0.sentenceAnalysis?.relationshipDiagram.nodes = [
          RelationshipNode(id: "node1", title: "Subject", text: "\n")
        ]
      }),
      ("sentenceAnalysis.logicSummary.title", { $0.sentenceAnalysis?.logicSummary.title = "" }),
      ("sentenceAnalysis.translation.title", { $0.sentenceAnalysis?.translation.title = "" }),
      ("sentenceAnalysis.translation.text", { $0.sentenceAnalysis?.translation.text = " " })
    ]

    for (field, mutate) in cases {
      var document = validSentenceDocument()
      mutate(&document)

      XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best."), field) { error in
        XCTAssertEqual(error as? LearningExplanationValidationError, .emptyRequiredField(field))
      }
    }
  }

  func testRejectsDuplicateStructureItemIDAcrossAncestorAndChild() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis?.structureBreakdown.items = [
      StructureItem(
        id: "dup",
        text: "Codex works best.",
        role: "sentence",
        labelZh: "句子",
        labelEn: "Sentence",
        children: [
          StructureItem(id: "dup", text: "Codex", role: "subject", labelZh: "主语", labelEn: "Subject", children: [])
        ]
      )
    ]

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .duplicateID("structureBreakdown.items", "dup"))
    }
  }

  func testRejectsDuplicateStructureItemIDAcrossBranches() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis?.structureBreakdown.items = [
      StructureItem(
        id: "first",
        text: "Codex",
        role: "subject",
        labelZh: "主语",
        labelEn: "Subject",
        children: [
          StructureItem(id: "shared", text: "Codex", role: "noun", labelZh: "名词", labelEn: "Noun", children: [])
        ]
      ),
      StructureItem(
        id: "second",
        text: "works best",
        role: "predicate",
        labelZh: "谓语",
        labelEn: "Predicate",
        children: [
          StructureItem(id: "shared", text: "best", role: "adverb", labelZh: "副词", labelEn: "Adverb", children: [])
        ]
      )
    ]

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .duplicateID("structureBreakdown.items", "shared"))
    }
  }

  func testRejectsEmptyStructureItemText() throws {
    let cases: [(String, [StructureItem])] = [
      (
        "sentenceAnalysis.structureBreakdown.items.root.text",
        [
          StructureItem(id: "root", text: " ", role: "sentence", labelZh: "句子", labelEn: "Sentence", children: [])
        ]
      ),
      (
        "sentenceAnalysis.structureBreakdown.items.child.text",
        [
          StructureItem(
            id: "root",
            text: "Codex works best.",
            role: "sentence",
            labelZh: "句子",
            labelEn: "Sentence",
            children: [
              StructureItem(id: "child", text: "\n", role: "subject", labelZh: "主语", labelEn: "Subject", children: [])
            ]
          )
        ]
      )
    ]

    for (field, items) in cases {
      var document = validSentenceDocument()
      document.sentenceAnalysis?.structureBreakdown.items = items

      XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best."), field) { error in
        XCTAssertEqual(error as? LearningExplanationValidationError, .emptyRequiredField(field))
      }
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
