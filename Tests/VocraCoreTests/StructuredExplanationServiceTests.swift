import Foundation
import Synchronization
import XCTest
@testable import VocraCore

final class StructuredExplanationServiceTests: XCTestCase {
  func testReturnsValidatedDocumentFromAIJSON() async throws {
    let aiClient = StubAIClient(responses: [Self.validSentenceJSON])
    let service = StructuredExplanationService(aiClient: aiClient)
    let captured = CapturedText(originalText: "Codex works best.", cleanedText: "Codex works best.", mode: .sentence, sourceApp: nil)
    let template = PromptTemplate(kind: .sentenceAnalysisSchema, body: "Analyze {{text}}.")

    let document = try await service.explain(captured: captured, template: template)

    XCTAssertEqual(document.mode, .sentence)
    XCTAssertEqual(aiClient.prompts.count, 1)
  }

  func testRetriesOnceWithRepairPromptAfterInvalidJSON() async throws {
    let aiClient = StubAIClient(responses: ["not json", Self.validSentenceJSON])
    let service = StructuredExplanationService(aiClient: aiClient)
    let captured = CapturedText(originalText: "Codex works best.", cleanedText: "Codex works best.", mode: .sentence, sourceApp: nil)
    let template = PromptTemplate(kind: .sentenceAnalysisSchema, body: "Analyze {{text}}.")

    _ = try await service.explain(captured: captured, template: template)

    XCTAssertEqual(aiClient.prompts.count, 2)
    XCTAssertTrue(aiClient.prompts[1].contains("Repair the JSON"))
  }

  func testReturnsValidatedVocabularyCardFromAIJSON() async throws {
    let aiClient = StubAIClient(responses: [Self.validVocabularyCardJSON])
    let service = StructuredExplanationService(aiClient: aiClient)
    let captured = CapturedText(originalText: "serendipity", cleanedText: "serendipity", mode: .word, sourceApp: nil)
    let template = PromptTemplate(kind: .vocabularyCardSchema, body: "Make a card for {{text}}.")

    let document = try await service.vocabularyCard(captured: captured, template: template)

    XCTAssertNotNil(document.vocabularyCard)
    XCTAssertEqual(document.vocabularyCard?.front.text, "serendipity")
    XCTAssertEqual(aiClient.prompts.count, 1)
  }

  private static let validSentenceJSON = """
  {
    "schemaVersion": 1,
    "mode": "sentence",
    "sourceText": "Codex works best.",
    "language": { "source": "en", "explanation": "zh-Hans" },
    "sentenceAnalysis": {
      "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
      "sentence": { "text": "Codex works best.", "segments": [] },
      "structureBreakdown": { "title": "结构解析", "items": [] },
      "relationshipDiagram": { "nodes": [], "edges": [] },
      "logicSummary": { "title": "核心含义", "points": ["主干清晰。"], "coreMeaning": "Codex 效果最好。" },
      "translation": { "title": "例句翻译", "text": "Codex 效果最好。" },
      "keyVocabulary": []
    },
    "wordExplanation": null,
    "vocabularyCard": null,
    "warnings": []
  }
  """

  private static let validVocabularyCardJSON = """
  {
    "schemaVersion": 1,
    "mode": "word",
    "sourceText": "serendipity",
    "language": { "source": "en", "explanation": "zh-Hans" },
    "sentenceAnalysis": null,
    "wordExplanation": null,
    "vocabularyCard": {
      "front": { "text": "serendipity", "hint": "unexpected good luck" },
      "back": {
        "coreMeaning": "意外发现美好事物的能力或好运。",
        "memoryNote": "Think of finding something valuable by chance.",
        "usage": "Use it for pleasant accidental discoveries."
      },
      "examples": [
        { "sentence": "Finding that cafe was pure serendipity.", "translation": "发现那家咖啡馆纯属意外之喜。" }
      ],
      "reviewPrompts": [
        "Use serendipity in a sentence."
      ]
    },
    "warnings": []
  }
  """
}

private final class StubAIClient: AIClient, @unchecked Sendable {
  private let state: Mutex<State>

  var prompts: [String] {
    state.withLock { $0.prompts }
  }

  init(responses: [String]) {
    self.state = Mutex(State(responses: responses))
  }

  func complete(prompt: String) async throws -> String {
    state.withLock {
      $0.prompts.append(prompt)
      return $0.responses.removeFirst()
    }
  }

  private struct State {
    var responses: [String]
    var prompts: [String] = []
  }
}
