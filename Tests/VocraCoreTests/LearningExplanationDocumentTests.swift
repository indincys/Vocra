import XCTest
@testable import VocraCore

final class LearningExplanationDocumentTests: XCTestCase {
  func testDecodesSentenceDocumentAndDefaultsUnknownColorToNeutral() throws {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "sentence",
      "sourceText": "Codex works best.",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": {
        "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
        "sentence": {
          "text": "Codex works best.",
          "segments": [
            { "id": "s1", "text": "Codex", "role": "subject", "labelZh": "主语", "labelEn": "Subject", "color": "cyan" }
          ]
        },
        "structureBreakdown": { "title": "结构解析", "items": [] },
        "relationshipDiagram": { "nodes": [], "edges": [] },
        "logicSummary": { "title": "核心含义", "points": ["Codex 是主语。"], "coreMeaning": "Codex 效果最好。" },
        "translation": { "title": "例句翻译", "text": "Codex 效果最好。" },
        "keyVocabulary": []
      },
      "wordExplanation": null,
      "vocabularyCard": null,
      "warnings": []
    }
    """

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))

    XCTAssertEqual(document.schemaVersion, 1)
    XCTAssertEqual(document.mode, .sentence)
    XCTAssertEqual(document.sentenceAnalysis?.sentence.segments.first?.color, .neutral)
  }

  func testDecodesPhraseDocumentUsingWordExplanationBranch() throws {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "phrase",
      "sourceText": "context window",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": null,
      "wordExplanation": {
        "term": "context window",
        "pronunciation": null,
        "partOfSpeech": "noun phrase",
        "coreMeaning": "上下文窗口",
        "contextualMeaning": "模型一次能参考的文本范围",
        "usageNotes": ["常用于大模型产品。"],
        "collocations": ["large context window"],
        "examples": [
          { "sentence": "This model has a large context window.", "translation": "这个模型有很大的上下文窗口。", "note": "描述能力范围。" }
        ],
        "commonMistakes": []
      },
      "vocabularyCard": null,
      "warnings": []
    }
    """

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))

    XCTAssertEqual(document.mode, .phrase)
    XCTAssertEqual(document.wordExplanation?.term, "context window")
  }
}
