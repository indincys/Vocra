import Foundation

public struct APIConfiguration: Codable, Equatable, Sendable {
  public var baseURL: URL
  public var model: String
  public var timeoutSeconds: Double
  /// Whether to send `response_format: {"type":"json_object"}`. Most OpenAI-compatible
  /// endpoints support it and it makes the model far more likely to return clean JSON,
  /// but a few self-hosted endpoints reject it — hence the per-config switch. The client
  /// also auto-retries without structured-output params on a 4xx as a safety net.
  public var supportsStructuredOutputs: Bool
  /// Optional sampling temperature. `nil` means "don't send it" — important because some
  /// reasoning models (e.g. the GPT-5 family) reject any non-default temperature.
  public var temperature: Double?
  /// Optional cap on generated tokens to keep a runaway generation from burning the whole
  /// request timeout. `nil` means "don't send it".
  public var maxTokens: Int?

  public init(
    baseURL: URL,
    model: String,
    timeoutSeconds: Double,
    supportsStructuredOutputs: Bool = true,
    temperature: Double? = nil,
    maxTokens: Int? = nil
  ) {
    self.baseURL = baseURL
    self.model = model
    self.timeoutSeconds = timeoutSeconds
    self.supportsStructuredOutputs = supportsStructuredOutputs
    self.temperature = temperature
    self.maxTokens = maxTokens
  }

  private enum CodingKeys: String, CodingKey {
    case baseURL, model, timeoutSeconds, supportsStructuredOutputs, temperature, maxTokens
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    baseURL = try container.decode(URL.self, forKey: .baseURL)
    model = try container.decode(String.self, forKey: .model)
    timeoutSeconds = try container.decode(Double.self, forKey: .timeoutSeconds)
    supportsStructuredOutputs = try container.decodeIfPresent(Bool.self, forKey: .supportsStructuredOutputs) ?? true
    temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
    maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
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
