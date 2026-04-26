import Foundation

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
    let apiKey = try apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let apiKey, !apiKey.isEmpty else {
      throw AIClientError.missingAPIKey
    }

    var request = URLRequest(url: configuration.baseURL.appending(path: "chat/completions"))
    request.httpMethod = "POST"
    request.timeoutInterval = configuration.timeoutSeconds
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(ChatCompletionRequest(
      model: configuration.model,
      temperature: configuration.temperature,
      messages: [
        RequestMessage(role: "user", content: prompt)
      ]
    ))

    let (data, response) = try await httpClient.data(for: request)
    guard (200..<300).contains(response.statusCode) else {
      throw AIClientError.httpStatus(response.statusCode)
    }

    do {
      let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
      guard let content = completion.choices.first?.message.content, !content.isEmpty else {
        throw AIClientError.emptyContent
      }
      return content
    } catch let error as AIClientError {
      throw error
    } catch {
      throw AIClientError.invalidResponse
    }
  }
}

private struct ChatCompletionRequest: Encodable {
  let model: String
  let temperature: Double
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
