import Foundation

public struct APIConfiguration: Codable, Equatable, Sendable {
  public var baseURL: URL
  public var model: String
  public var timeoutSeconds: Double

  public init(baseURL: URL, model: String, timeoutSeconds: Double) {
    self.baseURL = baseURL
    self.model = model
    self.timeoutSeconds = timeoutSeconds
  }

  public static let `default` = APIConfiguration(
    baseURL: URL(string: "https://api.openai.com/v1")!,
    model: "gpt-5.1-mini",
    timeoutSeconds: 45
  )
}

public struct APIProviderProfile: Codable, Equatable, Identifiable, Sendable {
  public static let defaultProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  public var id: UUID
  public var name: String
  public var configuration: APIConfiguration

  public init(id: UUID = UUID(), name: String, configuration: APIConfiguration) {
    self.id = id
    self.name = name
    self.configuration = configuration
  }

  public var keychainAccount: String {
    if id == Self.defaultProfileID {
      return KeychainAPIKeyStore.legacyAccount
    }
    return "\(KeychainAPIKeyStore.legacyAccount).\(id.uuidString)"
  }
}

public struct APIProviderSettings: Codable, Equatable, Sendable {
  public var profiles: [APIProviderProfile]
  public var activeProfileID: UUID

  public init(profiles: [APIProviderProfile], activeProfileID: UUID) {
    self.profiles = profiles
    self.activeProfileID = activeProfileID
  }

  public var activeProfile: APIProviderProfile? {
    profiles.first { $0.id == activeProfileID }
  }

  public static let `default` = APIProviderSettings(
    profiles: [
      APIProviderProfile(
        id: APIProviderProfile.defaultProfileID,
        name: "Default",
        configuration: .default
      )
    ],
    activeProfileID: APIProviderProfile.defaultProfileID
  )
}
