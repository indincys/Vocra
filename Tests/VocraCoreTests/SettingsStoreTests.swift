import Carbon
import XCTest
@testable import VocraCore

final class SettingsStoreTests: XCTestCase {
  func testDefaultAPIConfigurationUsesOpenAICompatibleDefaults() {
    XCTAssertEqual(APIConfiguration.default.baseURL.absoluteString, "https://api.openai.com/v1")
    XCTAssertEqual(APIConfiguration.default.model, "gpt-5.1-mini")
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
      timeoutSeconds: 30
    )

    store.saveAPIConfiguration(configuration)

    XCTAssertEqual(store.loadAPIConfiguration(), configuration)
  }

  func testDefaultAPIProviderSettingsContainsActiveDefaultProfile() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(defaults: defaults)

    let providerSettings = store.loadAPIProviderSettings()

    XCTAssertEqual(providerSettings.profiles.count, 1)
    XCTAssertEqual(providerSettings.activeProfileID, APIProviderProfile.defaultProfileID)
    XCTAssertEqual(providerSettings.activeProfile?.name, "Default")
    XCTAssertEqual(providerSettings.activeProfile?.configuration, .default)
    XCTAssertEqual(providerSettings.activeProfile?.keychainAccount, KeychainAPIKeyStore.legacyAccount)
  }

  func testUserDefaultsSettingsStorePersistsMultipleAPIProviderProfiles() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(defaults: defaults)
    let openAI = APIProviderProfile(
      id: APIProviderProfile.defaultProfileID,
      name: "OpenAI",
      configuration: APIConfiguration(baseURL: try XCTUnwrap(URL(string: "https://api.openai.com/v1")), model: "gpt-5.1-mini", timeoutSeconds: 45)
    )
    let anthropicID = UUID()
    let anthropic = APIProviderProfile(
      id: anthropicID,
      name: "Anthropic",
      configuration: APIConfiguration(baseURL: try XCTUnwrap(URL(string: "https://example.com/v1")), model: "claude-test", timeoutSeconds: 30)
    )
    let providerSettings = APIProviderSettings(profiles: [openAI, anthropic], activeProfileID: anthropicID)

    store.saveAPIProviderSettings(providerSettings)

    XCTAssertEqual(store.loadAPIProviderSettings(), providerSettings)
    XCTAssertEqual(store.loadAPIConfiguration(), anthropic.configuration)
    XCTAssertEqual(anthropic.keychainAccount, "OpenAICompatibleAPIKey.\(anthropicID.uuidString)")
  }

  func testSavingAPIConfigurationUpdatesActiveProviderProfile() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(defaults: defaults)
    let custom = APIConfiguration(
      baseURL: try XCTUnwrap(URL(string: "https://custom.example/v1")),
      model: "custom-model",
      timeoutSeconds: 20
    )

    store.saveAPIConfiguration(custom)

    XCTAssertEqual(store.loadAPIProviderSettings().activeProfile?.configuration, custom)
  }

  func testUserDefaultsSettingsStorePersistsKeyboardShortcut() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(defaults: defaults)
    let shortcut = KeyboardShortcut(keyCode: 8, modifiers: UInt32(cmdKey | optionKey))

    XCTAssertEqual(store.loadKeyboardShortcut(), .defaultShortcut)

    store.saveKeyboardShortcut(shortcut)

    XCTAssertEqual(store.loadKeyboardShortcut(), shortcut)
    XCTAssertEqual(store.loadKeyboardShortcut().displayString, "⌘⌥C")
  }

  func testUserDefaultsSettingsStorePersistsLearningPreferences() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(defaults: defaults)
    let preferences = LearningPreferences(
      explanationDepth: .detailed,
      exampleCount: 3,
      chineseStyle: .teacherLike,
      diagramDensity: .full
    )

    store.saveLearningPreferences(preferences)

    XCTAssertEqual(store.loadLearningPreferences(), preferences)
  }

  func testUserDefaultsSettingsStoreNormalizesLearningPreferenceExampleCount() throws {
    let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(defaults: defaults)

    store.saveLearningPreferences(LearningPreferences(
      explanationDepth: .standard,
      exampleCount: 999,
      chineseStyle: .concise,
      diagramDensity: .simple
    ))

    XCTAssertEqual(store.loadLearningPreferences().exampleCount, 3)

    let corruptedPreferences = LearningPreferences(
      explanationDepth: .detailed,
      exampleCount: 0,
      chineseStyle: .teacherLike,
      diagramDensity: .full
    )
    defaults.set(try JSONEncoder().encode(corruptedPreferences), forKey: "learningPreferences")

    XCTAssertEqual(store.loadLearningPreferences().exampleCount, 1)
  }
}
