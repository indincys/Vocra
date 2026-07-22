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
  /// Raw JSON object merged verbatim into the chat/completions request body. This is the
  /// escape hatch for provider-specific knobs that don't have a first-class field here —
  /// most importantly turning off a reasoning model's "thinking" pass, which every vendor
  /// spells differently (OpenAI/Gemini: `{"reasoning_effort":"none"}`; DeepSeek/Qwen:
  /// `{"enable_thinking":false}`; Doubao/Zhipu: `{"thinking":{"type":"disabled"}}`). Keys
  /// here override the typed fields above. Invalid JSON is ignored at send time.
  public var extraBody: String?

  public init(
    baseURL: URL,
    model: String,
    timeoutSeconds: Double,
    supportsStructuredOutputs: Bool = true,
    temperature: Double? = nil,
    maxTokens: Int? = nil,
    extraBody: String? = nil
  ) {
    self.baseURL = baseURL
    self.model = model
    self.timeoutSeconds = timeoutSeconds
    self.supportsStructuredOutputs = supportsStructuredOutputs
    self.temperature = temperature
    self.maxTokens = maxTokens
    self.extraBody = extraBody
  }

  private enum CodingKeys: String, CodingKey {
    case baseURL, model, timeoutSeconds, supportsStructuredOutputs, temperature, maxTokens, extraBody
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    baseURL = try container.decode(URL.self, forKey: .baseURL)
    model = try container.decode(String.self, forKey: .model)
    timeoutSeconds = try container.decode(Double.self, forKey: .timeoutSeconds)
    supportsStructuredOutputs = try container.decodeIfPresent(Bool.self, forKey: .supportsStructuredOutputs) ?? true
    temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
    maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
    extraBody = try container.decodeIfPresent(String.self, forKey: .extraBody)
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

  /// The account this profile's API key is stored under (see ``APIKeyStore``).
  public var secretAccount: String {
    APIKeyAccount.forProfile(id: id, isDefault: id == Self.defaultProfileID)
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
