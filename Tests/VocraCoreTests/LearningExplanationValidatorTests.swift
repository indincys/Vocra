import XCTest
@testable import VocraCore

final class LearningExplanationValidatorTests: XCTestCase {
  func testRejectsMissingActiveBranch() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis = nil

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .missingBranch("sentenceAnalysis"))
    }
  }

  func testRejectsBlankWordExplanationUserFacingFields() throws {
    let cases: [(String, (inout LearningExplanationDocument) -> Void)] = [
      ("wordExplanation.pronunciation", { $0.wordExplanation?.pronunciation = " " }),
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
      ("wordExplanation.examples[0].note", {
        $0.wordExplanation?.examples = [
          LearningExample(sentence: "The context window is large.", translation: "上下文窗口很大。", note: " ")
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
      ("vocabularyCard.front.hint", { $0.vocabularyCard?.front.hint = " " }),
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
      ("sentenceAnalysis.translation.text", { $0.sentenceAnalysis?.translation.text = " " }),
      ("sentenceAnalysis.sentence.segments.s1.labelZh", {
        $0.sentenceAnalysis?.sentence.segments = [
          SentenceSegment(id: "s1", text: "Codex", role: "subject", labelZh: " ", labelEn: "Subject", color: .blue)
        ]
      }),
      ("sentenceAnalysis.keyVocabulary[0].term", {
        $0.sentenceAnalysis?.keyVocabulary = [KeyVocabularyItem(term: " ", meaning: "最好", note: "")]
      }),
      ("sentenceAnalysis.keyVocabulary[0].meaning", {
        $0.sentenceAnalysis?.keyVocabulary = [KeyVocabularyItem(term: "best", meaning: "\n", note: "")]
      })
    ]

    for (field, mutate) in cases {
      var document = validSentenceDocument()
      mutate(&document)

      XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best."), field) { error in
        XCTAssertEqual(error as? LearningExplanationValidationError, .emptyRequiredField(field))
      }
    }
  }

  /// Key vocabulary streams in after the segments, so an empty list mid-stream is valid.
  func testAcceptsSentenceWithoutKeyVocabulary() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis?.keyVocabulary = []

    XCTAssertNoThrow(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best."))
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
        sentence: AnalyzedSentence(
          text: "Codex works best.",
          segments: [
            SentenceSegment(id: "s1", text: "Codex", role: "subject", labelZh: "主语", labelEn: "Subject", color: .blue)
          ]
        ),
        translation: TranslationBlock(title: "例句翻译", text: "Codex 效果最好。"),
        keyVocabulary: [KeyVocabularyItem(term: "best", meaning: "最好", note: "")]
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
