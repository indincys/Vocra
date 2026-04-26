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
