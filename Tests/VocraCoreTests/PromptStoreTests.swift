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

  func testPromptKindDecodesDeprecatedRawValues() throws {
    let decoded = try JSONDecoder().decode(PromptKind.self, from: Data(#""phraseExplanation""#.utf8))

    XCTAssertEqual(decoded, .phraseExplanation)
  }

  func testUserDefaultsPromptStorePreservesDistinctDeprecatedWordAndPhrasePrompts() {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let store = UserDefaultsPromptStore(defaults: defaults)
    store.save(PromptTemplate(kind: .wordExplanation, body: "Custom word prompt"))
    store.save(PromptTemplate(kind: .phraseExplanation, body: "Custom phrase prompt"))

    let reloaded = UserDefaultsPromptStore(defaults: defaults)

    XCTAssertEqual(reloaded.template(for: .wordExplanation)?.body, "Custom word prompt")
    XCTAssertEqual(reloaded.template(for: .phraseExplanation)?.body, "Custom phrase prompt")
  }

  func testUserDefaultsPromptStoreFallsBackFromDeprecatedKindsToSchemaTemplates() {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let store = UserDefaultsPromptStore(defaults: defaults)

    XCTAssertEqual(store.template(for: .wordExplanation)?.kind, .wordExplanationSchema)
    XCTAssertEqual(store.template(for: .phraseExplanation)?.kind, .wordExplanationSchema)
    XCTAssertEqual(store.template(for: .sentenceExplanation)?.kind, .sentenceAnalysisSchema)
    XCTAssertEqual(store.template(for: .vocabularyCard)?.kind, .vocabularyCardSchema)
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
