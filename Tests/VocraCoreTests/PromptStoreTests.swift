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
}

private struct PersistedPromptRecord: Decodable {
  var kind: String
}
