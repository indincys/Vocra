import XCTest
@testable import VocraCore

final class LearningExplanationDocumentTests: XCTestCase {
  func testDecodesSentenceDocumentWhenSentenceFieldIsPlainString() throws {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "sentence",
      "sourceText": "Codex works best.",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": {
        "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
        "sentence": "Codex works best.",
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

    XCTAssertEqual(document.sentenceAnalysis?.sentence.text, "Codex works best.")
    XCTAssertEqual(document.sentenceAnalysis?.sentence.segments, [])
  }

  func testDecodesSentenceRelationshipEdgeWhenChineseLabelIsMissing() throws {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "sentence",
      "sourceText": "Codex works best when configured.",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": {
        "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
        "sentence": { "text": "Codex works best when configured.", "segments": [] },
        "structureBreakdown": { "title": "结构解析", "items": [] },
        "relationshipDiagram": {
          "nodes": [
            { "id": "main", "title": "主句", "text": "Codex works best" },
            { "id": "condition", "title": "条件", "text": "when configured" }
          ],
          "edges": [
            { "from": "condition", "to": "main", "labelEn": "condition / time" }
          ]
        },
        "logicSummary": { "title": "核心含义", "points": ["when configured 说明条件。"], "coreMeaning": "配置好时效果最好。" },
        "translation": { "title": "例句翻译", "text": "配置好时，Codex 效果最好。" },
        "keyVocabulary": []
      },
      "wordExplanation": null,
      "vocabularyCard": null,
      "warnings": []
    }
    """

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))

    XCTAssertEqual(document.sentenceAnalysis?.relationshipDiagram.edges.first?.labelZh, "关系")
    XCTAssertEqual(document.sentenceAnalysis?.relationshipDiagram.edges.first?.labelEn, "condition / time")
  }

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

  func testDecodesWordDocumentWhenListFieldsArePlainStrings() throws {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "word",
      "sourceText": "configure",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": null,
      "wordExplanation": {
        "term": "configure",
        "pronunciation": "/kənˈfɪɡjər/",
        "partOfSpeech": "verb",
        "coreMeaning": "配置；设定",
        "contextualMeaning": "根据需求进行设置和调整",
        "usageNotes": "常用于软件、系统、工具或参数。",
        "collocations": "configure settings",
        "examples": [
          { "sentence": "You can configure the tool.", "translation": "你可以配置这个工具。", "note": null }
        ],
        "commonMistakes": "不要把 configure 简单理解成 install。"
      },
      "vocabularyCard": null,
      "warnings": []
    }
    """

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))

    XCTAssertEqual(document.wordExplanation?.usageNotes, ["常用于软件、系统、工具或参数。"])
    XCTAssertEqual(document.wordExplanation?.collocations, ["configure settings"])
    XCTAssertEqual(document.wordExplanation?.commonMistakes, ["不要把 configure 简单理解成 install。"])
  }
}
