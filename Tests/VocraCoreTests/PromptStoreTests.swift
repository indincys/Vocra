import XCTest
@testable import VocraCore

final class PromptStoreTests: XCTestCase {
  func testDefaultPromptStoreUsesSchemaPromptKinds() {
    let store = InMemoryPromptStore.defaults()

    XCTAssertNotNil(store.template(for: .sentenceAnalysisSchema))
    XCTAssertNotNil(store.template(for: .wordExplanationSchema))
    XCTAssertNotNil(store.template(for: .vocabularyCardSchema))
    XCTAssertEqual(PromptKind.allCases, [.sentenceAnalysisSchema, .wordExplanationSchema, .vocabularyCardSchema])
  }

  func testDefaultSentencePromptIncludesConcreteNestedSchemaShape() throws {
    let prompt = try XCTUnwrap(InMemoryPromptStore.defaults().template(for: .sentenceAnalysisSchema)?.body)

    XCTAssertTrue(prompt.contains(#""sentence": { "text": "<selected sentence>", "segments": ["#))
    XCTAssertTrue(prompt.contains(#""wordExplanation": null"#))
    XCTAssertTrue(prompt.contains(#""vocabularyCard": null"#))
  }

  func testUserDefaultsPromptStorePersistsCustomPrompt() {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let store = UserDefaultsPromptStore(defaults: defaults)
    let replacement = PromptTemplate(kind: .sentenceAnalysisSchema, body: "Custom sentence prompt for {{text}}")
    store.save(replacement)

    let reloaded = UserDefaultsPromptStore(defaults: defaults)

    XCTAssertEqual(reloaded.template(for: .sentenceAnalysisSchema)?.body, "Custom sentence prompt for {{text}}")
  }

  func testUserDefaultsPromptStorePreservesSchemaPromptsWhenLegacyPromptKindsExist() throws {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let persistedJSON = """
    [
      { "kind": "wordExplanation", "body": "Legacy word prompt" },
      { "kind": "sentenceAnalysisSchema", "body": "Custom sentence schema prompt" }
    ]
    """
    defaults.set(Data(persistedJSON.utf8), forKey: "vocra.promptTemplates")

    let store = UserDefaultsPromptStore(defaults: defaults)

    XCTAssertEqual(store.template(for: .sentenceAnalysisSchema)?.body, "Custom sentence schema prompt")
    XCTAssertEqual(Set(store.allTemplates().map(\.kind)), Set(PromptKind.allCases))

    let migratedData = try XCTUnwrap(defaults.data(forKey: "vocra.promptTemplates"))
    let migratedRecords = try JSONDecoder().decode([PersistedPromptRecord].self, from: migratedData)
    XCTAssertEqual(Set(migratedRecords.map(\.kind)), Set(PromptKind.allCases.map(\.rawValue)))
  }

  func testUserDefaultsPromptStoreUpgradesBundledDefaultSchemaPrompts() throws {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let legacySentencePrompt = """
    Return a single JSON object for a deep Chinese learning analysis of this English sentence.
    The object must match LearningExplanationDocument schemaVersion 1.
    Use mode "sentence".
    Include sentenceAnalysis with headline, sentence.segments, structureBreakdown, relationshipDiagram, logicSummary, translation, and keyVocabulary.
    Do not include Markdown fences or prose outside JSON.
    Text: {{text}}
    Source app: {{sourceApp}}
    Created at: {{createdAt}}
    """
    let persistedJSON = """
    [
      { "kind": "sentenceAnalysisSchema", "body": \(jsonString(legacySentencePrompt)) },
      { "kind": "wordExplanationSchema", "body": "Custom word schema prompt" },
      { "kind": "vocabularyCardSchema", "body": "Custom card schema prompt" }
    ]
    """
    defaults.set(Data(persistedJSON.utf8), forKey: "vocra.promptTemplates")

    let store = UserDefaultsPromptStore(defaults: defaults)

    XCTAssertNotEqual(store.template(for: .sentenceAnalysisSchema)?.body, legacySentencePrompt)
    XCTAssertEqual(store.template(for: .wordExplanationSchema)?.body, "Custom word schema prompt")
    XCTAssertEqual(store.template(for: .vocabularyCardSchema)?.body, "Custom card schema prompt")
    XCTAssertTrue(try XCTUnwrap(store.template(for: .sentenceAnalysisSchema)?.body).contains(#""sentence": { "text": "<selected sentence>", "segments": ["#))
  }

  func testUserDefaultsPromptStoreUpgradesPreviousStructuredSentencePrompt() throws {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let previousStructuredPrompt = """
    Return a single JSON object for a deep Chinese learning analysis of this English sentence.
    Use exactly this root shape and JSON value types. Do not replace nested objects with strings.
    "sentence": { "text": "<selected sentence>", "segments": [
    "edges": []
    Segment colors must be one of: blue, green, orange, purple, pink, neutral.
    """
    let persistedJSON = """
    [
      { "kind": "sentenceAnalysisSchema", "body": \(jsonString(previousStructuredPrompt)) }
    ]
    """
    defaults.set(Data(persistedJSON.utf8), forKey: "vocra.promptTemplates")

    let store = UserDefaultsPromptStore(defaults: defaults)
    let upgraded = try XCTUnwrap(store.template(for: .sentenceAnalysisSchema)?.body)

    XCTAssertTrue(upgraded.contains(#""labelZh": "在这种情境下""#))
    XCTAssertFalse(upgraded.contains(#""edges": []"#))
  }
}

private struct PersistedPromptRecord: Decodable {
  var kind: String
}

private func jsonString(_ value: String) -> String {
  let data = try! JSONEncoder().encode(value)
  return String(data: data, encoding: .utf8)!
}
