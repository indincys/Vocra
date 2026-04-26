import Foundation
import OSLog

private let aiClientLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "AIClient"
)

public protocol HTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await data(for: request, delegate: nil)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AIClientError.invalidResponse
    }
    return (data, httpResponse)
  }
}

public struct OpenAICompatibleClient: AIClient {
  private let configuration: APIConfiguration
  private let apiKeyProvider: @Sendable () throws -> String?
  private let httpClient: any HTTPClient

  public init(
    configuration: APIConfiguration,
    apiKeyProvider: @escaping @Sendable () throws -> String?,
    httpClient: any HTTPClient = URLSession.shared
  ) {
    self.configuration = configuration
    self.apiKeyProvider = apiKeyProvider
    self.httpClient = httpClient
  }

  public func complete(prompt: String) async throws -> String {
    let clock = ContinuousClock()
    let requestStart = clock.now
    let apiKey = try apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let apiKey, !apiKey.isEmpty else {
      aiClientLogger.error("AI request cannot start because the API key is missing.")
      throw AIClientError.missingAPIKey
    }

    var request = URLRequest(url: configuration.baseURL.appending(path: "chat/completions"))
    request.httpMethod = "POST"
    request.timeoutInterval = configuration.timeoutSeconds
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(ChatCompletionRequest(
      model: configuration.model,
      messages: [
        RequestMessage(role: "user", content: prompt)
      ]
    ))

    aiClientLogger.info(
      "AI request started; model: \(configuration.model, privacy: .public); endpoint: \(request.url?.absoluteString ?? "Unknown URL", privacy: .public); prompt characters: \(prompt.count, privacy: .public)."
    )
    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await httpClient.data(for: request)
    } catch {
      aiClientLogger.error(
        "AI request failed after \(aiElapsedMilliseconds(from: requestStart, clock: clock), privacy: .public) ms: \(String(describing: error), privacy: .public)"
      )
      throw error
    }
    aiClientLogger.info(
      "AI response received in \(aiElapsedMilliseconds(from: requestStart, clock: clock), privacy: .public) ms; status: \(response.statusCode, privacy: .public); bytes: \(data.count, privacy: .public)."
    )
    guard (200..<300).contains(response.statusCode) else {
      aiClientLogger.error("AI response returned non-success status: \(response.statusCode, privacy: .public).")
      throw AIClientError.httpStatus(response.statusCode)
    }

    do {
      let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
      guard let content = completion.choices.first?.message.content, !content.isEmpty else {
        aiClientLogger.error("AI response decoded with empty content.")
        throw AIClientError.emptyContent
      }
      aiClientLogger.info("AI response decoded; content characters: \(content.count, privacy: .public).")
      return content
    } catch let error as AIClientError {
      throw error
    } catch {
      aiClientLogger.error("AI response decoding failed: \(String(describing: error), privacy: .public)")
      throw AIClientError.invalidResponse
    }
  }
}

private func aiElapsedMilliseconds(from start: ContinuousClock.Instant, clock: ContinuousClock) -> Int64 {
  let components = start.duration(to: clock.now).components
  return components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
}

private struct ChatCompletionRequest: Encodable {
  let model: String
  let messages: [RequestMessage]
}

private struct RequestMessage: Encodable {
  let role: String
  let content: String
}

private struct ChatCompletionResponse: Decodable {
  let choices: [Choice]
}

private struct Choice: Decodable {
  let message: ResponseMessage
}

private struct ResponseMessage: Decodable {
  let content: String?
}
