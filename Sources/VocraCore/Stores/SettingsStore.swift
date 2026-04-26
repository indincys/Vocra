import Foundation

public protocol SettingsStore: Sendable {
  func loadAPIConfiguration() -> APIConfiguration
  func saveAPIConfiguration(_ configuration: APIConfiguration)
  func loadKeyboardShortcut() -> KeyboardShortcut
  func saveKeyboardShortcut(_ shortcut: KeyboardShortcut)
}

public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let apiConfigurationKey = "apiConfiguration"
  private let keyboardShortcutKey = "keyboardShortcut"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func loadAPIConfiguration() -> APIConfiguration {
    guard
      let data = defaults.data(forKey: apiConfigurationKey),
      let configuration = try? JSONDecoder().decode(APIConfiguration.self, from: data)
    else {
      return .default
    }
    return configuration
  }

  public func saveAPIConfiguration(_ configuration: APIConfiguration) {
    guard let data = try? JSONEncoder().encode(configuration) else { return }
    defaults.set(data, forKey: apiConfigurationKey)
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
}
