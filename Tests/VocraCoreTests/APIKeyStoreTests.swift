import XCTest
@testable import VocraCore

final class APIKeyStoreTests: XCTestCase {
  func testSaveReadUpdateAndDeleteAPIKey() throws {
    let store = KeychainAPIKeyStore(
      service: "com.indincys.Vocra.tests.\(UUID().uuidString)",
      account: "OpenAICompatibleAPIKeyTests"
    )
    defer { try? store.deleteAPIKey() }

    XCTAssertNil(try store.readAPIKey())

    try store.saveAPIKey("first-key")
    XCTAssertEqual(try store.readAPIKey(), "first-key")

    try store.saveAPIKey("updated-key")
    XCTAssertEqual(try store.readAPIKey(), "updated-key")

    try store.deleteAPIKey()
    XCTAssertNil(try store.readAPIKey())
  }
}
