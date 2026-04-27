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
}
