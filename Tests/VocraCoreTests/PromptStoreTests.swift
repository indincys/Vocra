import XCTest
@testable import VocraCore

final class PromptStoreTests: XCTestCase {
  func testUserDefaultsPromptStorePersistsCustomPrompt() {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let store = UserDefaultsPromptStore(defaults: defaults)
    let replacement = PromptTemplate(kind: .sentenceExplanation, body: "Custom sentence prompt for {{text}}")
    store.save(replacement)

    let reloaded = UserDefaultsPromptStore(defaults: defaults)

    XCTAssertEqual(reloaded.template(for: .sentenceExplanation)?.body, "Custom sentence prompt for {{text}}")
  }
}
