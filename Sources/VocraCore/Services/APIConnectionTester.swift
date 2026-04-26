import Foundation

public struct APIConnectionTester: Sendable {
  private let httpClient: any HTTPClient

  public init(httpClient: any HTTPClient = URLSession.shared) {
    self.httpClient = httpClient
  }

  public func test(configuration: APIConfiguration, apiKey: String) async throws {
    let client = OpenAICompatibleClient(
      configuration: configuration,
      apiKeyProvider: { apiKey },
      httpClient: httpClient
    )
    _ = try await client.complete(prompt: "Reply with OK.")
  }
}
