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

  func testRejectsBlankWordExplanationUserFacingFields() throws {
    let cases: [(String, (inout LearningExplanationDocument) -> Void)] = [
      ("wordExplanation.partOfSpeech", { $0.wordExplanation?.partOfSpeech = " " }),
      ("wordExplanation.contextualMeaning", { $0.wordExplanation?.contextualMeaning = "" }),
      ("wordExplanation.examples[0].sentence", {
        $0.wordExplanation?.examples = [
          LearningExample(sentence: "\n", translation: "上下文窗口很大。", note: nil)
        ]
      }),
      ("wordExplanation.examples[0].translation", {
        $0.wordExplanation?.examples = [
          LearningExample(sentence: "The context window is large.", translation: "", note: nil)
        ]
      }),
      ("wordExplanation.usageNotes[0]", { $0.wordExplanation?.usageNotes = [" "] }),
      ("wordExplanation.collocations[0]", { $0.wordExplanation?.collocations = [""] }),
      ("wordExplanation.commonMistakes[0]", { $0.wordExplanation?.commonMistakes = ["\n"] })
    ]

    for (field, mutate) in cases {
      var document = validWordDocument()
      mutate(&document)

      XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .word, expectedSourceText: "context window"), field) { error in
        XCTAssertEqual(error as? LearningExplanationValidationError, .emptyRequiredField(field))
      }
    }
  }

  func testRejectsBlankVocabularyCardUserFacingFields() throws {
    let cases: [(String, (inout LearningExplanationDocument) -> Void)] = [
      ("vocabularyCard.back.memoryNote", { $0.vocabularyCard?.back.memoryNote = " " }),
      ("vocabularyCard.back.usage", { $0.vocabularyCard?.back.usage = "" }),
      ("vocabularyCard.examples[0].sentence", {
        $0.vocabularyCard?.examples = [
          VocabularyCardExample(sentence: "\n", translation: "上下文窗口很大。")
        ]
      }),
      ("vocabularyCard.examples[0].translation", {
        $0.vocabularyCard?.examples = [
          VocabularyCardExample(sentence: "The context window is large.", translation: "")
        ]
      }),
      ("vocabularyCard.reviewPrompts[0]", { $0.vocabularyCard?.reviewPrompts = [" "] })
    ]

    for (field, mutate) in cases {
      var document = validVocabularyCardDocument()
      mutate(&document)

      XCTAssertThrowsError(try LearningExplanationValidator().validateVocabularyCard(document, expectedMode: .word, expectedSourceText: "context window"), field) { error in
        XCTAssertEqual(error as? LearningExplanationValidationError, .emptyRequiredField(field))
      }
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

  func testRejectsInvalidRelationshipEdges() throws {
    let cases: [(LearningExplanationValidationError, (inout LearningExplanationDocument) -> Void)] = [
      (.emptyRequiredField("sentenceAnalysis.relationshipDiagram.edges[0].from"), {
        $0.sentenceAnalysis?.relationshipDiagram = RelationshipDiagram(
          nodes: [
            RelationshipNode(id: "subject", title: "Subject", text: "Codex"),
            RelationshipNode(id: "predicate", title: "Predicate", text: "works best")
          ],
          edges: [
            RelationshipEdge(from: " ", to: "predicate", labelZh: "说明", labelEn: "describes")
          ]
        )
      }),
      (.emptyRequiredField("sentenceAnalysis.relationshipDiagram.edges[0].to"), {
        $0.sentenceAnalysis?.relationshipDiagram = RelationshipDiagram(
          nodes: [
            RelationshipNode(id: "subject", title: "Subject", text: "Codex"),
            RelationshipNode(id: "predicate", title: "Predicate", text: "works best")
          ],
          edges: [
            RelationshipEdge(from: "subject", to: "", labelZh: "说明", labelEn: "describes")
          ]
        )
      }),
      (.emptyRequiredField("sentenceAnalysis.relationshipDiagram.edges[0].labelZh"), {
        $0.sentenceAnalysis?.relationshipDiagram = RelationshipDiagram(
          nodes: [
            RelationshipNode(id: "subject", title: "Subject", text: "Codex"),
            RelationshipNode(id: "predicate", title: "Predicate", text: "works best")
          ],
          edges: [
            RelationshipEdge(from: "subject", to: "predicate", labelZh: "\n", labelEn: "describes")
          ]
        )
      }),
      (.emptyRequiredField("sentenceAnalysis.relationshipDiagram.edges[0].labelEn"), {
        $0.sentenceAnalysis?.relationshipDiagram = RelationshipDiagram(
          nodes: [
            RelationshipNode(id: "subject", title: "Subject", text: "Codex"),
            RelationshipNode(id: "predicate", title: "Predicate", text: "works best")
          ],
          edges: [
            RelationshipEdge(from: "subject", to: "predicate", labelZh: "说明", labelEn: " ")
          ]
        )
      }),
      (.unknownRelationshipNodeReference(field: "sentenceAnalysis.relationshipDiagram.edges[0].from", id: "missing"), {
        $0.sentenceAnalysis?.relationshipDiagram = RelationshipDiagram(
          nodes: [
            RelationshipNode(id: "subject", title: "Subject", text: "Codex"),
            RelationshipNode(id: "predicate", title: "Predicate", text: "works best")
          ],
          edges: [
            RelationshipEdge(from: "missing", to: "predicate", labelZh: "说明", labelEn: "describes")
          ]
        )
      }),
      (.unknownRelationshipNodeReference(field: "sentenceAnalysis.relationshipDiagram.edges[0].to", id: "missing"), {
        $0.sentenceAnalysis?.relationshipDiagram = RelationshipDiagram(
          nodes: [
            RelationshipNode(id: "subject", title: "Subject", text: "Codex"),
            RelationshipNode(id: "predicate", title: "Predicate", text: "works best")
          ],
          edges: [
            RelationshipEdge(from: "subject", to: "missing", labelZh: "说明", labelEn: "describes")
          ]
        )
      })
    ]

    for (expectedError, mutate) in cases {
      var document = validSentenceDocument()
      mutate(&document)

      XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best."), "\(expectedError)") { error in
        XCTAssertEqual(error as? LearningExplanationValidationError, expectedError)
      }
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

  private func validWordDocument() -> LearningExplanationDocument {
    LearningExplanationDocument(
      schemaVersion: 1,
      mode: .word,
      sourceText: "context window",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: WordExplanation(
        term: "context window",
        pronunciation: nil,
        partOfSpeech: "noun phrase",
        coreMeaning: "上下文窗口",
        contextualMeaning: "模型一次能参考的文本范围",
        usageNotes: ["常用于大模型产品。"],
        collocations: ["large context window"],
        examples: [
          LearningExample(sentence: "The context window is large.", translation: "上下文窗口很大。", note: nil)
        ],
        commonMistakes: ["不要写成 content window。"]
      ),
      vocabularyCard: nil,
      warnings: []
    )
  }

  private func validVocabularyCardDocument() -> LearningExplanationDocument {
    LearningExplanationDocument(
      schemaVersion: 1,
      mode: .word,
      sourceText: "context window",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: nil,
      vocabularyCard: StructuredVocabularyCard(
        front: VocabularyCardFront(text: "context window", hint: "LLM limit"),
        back: VocabularyCardBack(coreMeaning: "上下文窗口", memoryNote: "想象模型能看到的一扇窗口。", usage: "常用于描述模型能参考的文本范围。"),
        examples: [
          VocabularyCardExample(sentence: "The context window is large.", translation: "上下文窗口很大。")
        ],
        reviewPrompts: ["context window 是什么意思？"]
      ),
      warnings: []
    )
  }
}
