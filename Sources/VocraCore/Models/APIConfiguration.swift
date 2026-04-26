import Foundation

public struct APIConfiguration: Codable, Equatable, Sendable {
  public var baseURL: URL
  public var model: String
  public var temperature: Double
  public var timeoutSeconds: Double

  public init(baseURL: URL, model: String, temperature: Double, timeoutSeconds: Double) {
    self.baseURL = baseURL
    self.model = model
    self.temperature = temperature
    self.timeoutSeconds = timeoutSeconds
  }

  public static let `default` = APIConfiguration(
    baseURL: URL(string: "https://api.openai.com/v1")!,
    model: "gpt-5.1-mini",
    temperature: 0.2,
    timeoutSeconds: 45
  )
}
