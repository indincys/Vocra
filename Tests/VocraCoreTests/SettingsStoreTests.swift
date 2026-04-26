import XCTest
@testable import VocraCore

final class SettingsStoreTests: XCTestCase {
  func testDefaultAPIConfigurationUsesOpenAICompatibleDefaults() {
    XCTAssertEqual(APIConfiguration.default.baseURL.absoluteString, "https://api.openai.com/v1")
    XCTAssertEqual(APIConfiguration.default.model, "gpt-5.1-mini")
    XCTAssertEqual(APIConfiguration.default.temperature, 0.2)
    XCTAssertEqual(APIConfiguration.default.timeoutSeconds, 45)
  }

  func testUserDefaultsSettingsStorePersistsAPIConfiguration() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(defaults: defaults)
    let configuration = APIConfiguration(
      baseURL: try XCTUnwrap(URL(string: "https://example.com/v1")),
      model: "custom-model",
      temperature: 0.7,
      timeoutSeconds: 30
    )

    store.saveAPIConfiguration(configuration)

    XCTAssertEqual(store.loadAPIConfiguration(), configuration)
  }
}
