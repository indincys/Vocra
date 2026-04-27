import Foundation

public protocol SettingsStore: Sendable {
  func loadAPIConfiguration() -> APIConfiguration
  func saveAPIConfiguration(_ configuration: APIConfiguration)
  func loadAPIProviderSettings() -> APIProviderSettings
  func saveAPIProviderSettings(_ settings: APIProviderSettings)
  func loadKeyboardShortcut() -> KeyboardShortcut
  func saveKeyboardShortcut(_ shortcut: KeyboardShortcut)
  func loadLearningPreferences() -> LearningPreferences
  func saveLearningPreferences(_ preferences: LearningPreferences)
}

public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let apiConfigurationKey = "apiConfiguration"
  private let apiProviderSettingsKey = "apiProviderSettings"
  private let keyboardShortcutKey = "keyboardShortcut"
  private let learningPreferencesKey = "learningPreferences"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func loadAPIConfiguration() -> APIConfiguration {
    if let activeProfile = loadPersistedAPIProviderSettings()?.activeProfile {
      return activeProfile.configuration
    }
    return loadLegacyAPIConfiguration()
  }

  public func saveAPIConfiguration(_ configuration: APIConfiguration) {
    var providerSettings = loadAPIProviderSettings()
    if let activeIndex = providerSettings.profiles.firstIndex(where: { $0.id == providerSettings.activeProfileID }) {
      providerSettings.profiles[activeIndex].configuration = configuration
    } else {
      providerSettings = .default
      providerSettings.profiles[0].configuration = configuration
    }
    saveAPIProviderSettings(providerSettings)

    guard let data = try? JSONEncoder().encode(configuration) else { return }
    defaults.set(data, forKey: apiConfigurationKey)
  }

  public func loadAPIProviderSettings() -> APIProviderSettings {
    loadPersistedAPIProviderSettings() ?? APIProviderSettings(
      profiles: [
        APIProviderProfile(
          id: APIProviderProfile.defaultProfileID,
          name: "Default",
          configuration: loadLegacyAPIConfiguration()
        )
      ],
      activeProfileID: APIProviderProfile.defaultProfileID
    )
  }

  public func saveAPIProviderSettings(_ settings: APIProviderSettings) {
    let normalized = normalizedAPIProviderSettings(settings)
    guard let data = try? JSONEncoder().encode(normalized) else { return }
    defaults.set(data, forKey: apiProviderSettingsKey)
    if let activeConfiguration = normalized.activeProfile?.configuration,
      let legacyData = try? JSONEncoder().encode(activeConfiguration) {
      defaults.set(legacyData, forKey: apiConfigurationKey)
    }
  }

  public func loadKeyboardShortcut() -> KeyboardShortcut {
    guard
      let data = defaults.data(forKey: keyboardShortcutKey),
      let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data),
      shortcut.isValid
    else {
      return .defaultShortcut
    }
    return shortcut
  }

  public func saveKeyboardShortcut(_ shortcut: KeyboardShortcut) {
    guard shortcut.isValid, let data = try? JSONEncoder().encode(shortcut) else { return }
    defaults.set(data, forKey: keyboardShortcutKey)
  }

  public func loadLearningPreferences() -> LearningPreferences {
    guard
      let data = defaults.data(forKey: learningPreferencesKey),
      let preferences = try? JSONDecoder().decode(LearningPreferences.self, from: data)
    else {
      return .default
    }
    return preferences
  }

  public func saveLearningPreferences(_ preferences: LearningPreferences) {
    guard let data = try? JSONEncoder().encode(preferences) else { return }
    defaults.set(data, forKey: learningPreferencesKey)
  }

  private func loadLegacyAPIConfiguration() -> APIConfiguration {
    guard
      let data = defaults.data(forKey: apiConfigurationKey),
      let configuration = try? JSONDecoder().decode(APIConfiguration.self, from: data)
    else {
      return .default
    }
    return configuration
  }

  private func loadPersistedAPIProviderSettings() -> APIProviderSettings? {
    guard
      let data = defaults.data(forKey: apiProviderSettingsKey),
      let settings = try? JSONDecoder().decode(APIProviderSettings.self, from: data)
    else { return nil }
    return normalizedAPIProviderSettings(settings)
  }

  private func normalizedAPIProviderSettings(_ settings: APIProviderSettings) -> APIProviderSettings {
    var profiles = settings.profiles
    if profiles.isEmpty {
      profiles = APIProviderSettings.default.profiles
    }
    let activeProfileID = profiles.contains { $0.id == settings.activeProfileID }
      ? settings.activeProfileID
      : profiles[0].id
    return APIProviderSettings(profiles: profiles, activeProfileID: activeProfileID)
  }
}
