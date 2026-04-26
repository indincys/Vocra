import Foundation

public protocol SettingsStore: Sendable {
  func loadAPIConfiguration() -> APIConfiguration
  func saveAPIConfiguration(_ configuration: APIConfiguration)
}

public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let apiConfigurationKey = "apiConfiguration"

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
}
