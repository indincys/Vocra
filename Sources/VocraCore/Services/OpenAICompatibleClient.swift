import Foundation
import OSLog

private let aiClientLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "AIClient"
)

public protocol HTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
  /// Streams an HTTP response line-by-line. Streaming keeps the connection
  /// active so `URLRequest.timeoutInterval` (an *idle* timeout) doesn't trip
  /// during a long single-shot model generation.
  func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, HTTPURLResponse)
}

public extension HTTPClient {
  /// Default: fall back to a buffered request and emit the whole body as one
  /// chunk. Keeps non-streaming clients (tests, connectivity checks) working
  /// and gracefully handles providers that ignore `stream`.
  func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, HTTPURLResponse) {
    let (data, response) = try await data(for: request)
    let body = String(decoding: data, as: UTF8.self)
    let stream = AsyncThrowingStream<String, Error> { continuation in
      continuation.yield(body)
      continuation.finish()
    }
    return (stream, response)
  }
}

extension URLSession: HTTPClient {
  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await data(for: request, delegate: nil)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AIClientError.invalidResponse
    }
    return (data, httpResponse)
  }

  public func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, HTTPURLResponse) {
    let (bytes, response) = try await bytes(for: request, delegate: nil)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AIClientError.invalidResponse
    }
    let stream = AsyncThrowingStream<String, Error> { continuation in
      let task = Task {
        do {
          for try await line in bytes.lines {
            continuation.yield(line)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
    return (stream, httpResponse)
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
    try await complete(prompt: prompt, onPartial: { _ in })
  }

  public func complete(prompt: String, onPartial: @escaping @Sendable (String) -> Void) async throws -> String {
    let clock = ContinuousClock()
    let requestStart = clock.now
    let apiKey = try apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let apiKey, !apiKey.isEmpty else {
      aiClientLogger.error("AI request cannot start because the API key is missing.")
      throw AIClientError.missingAPIKey
    }

    // Send the tuned body (structured output / temperature / max_tokens) first. If the
    // endpoint rejects it with a 4xx, those extras are the most likely culprit, so retry
    // once with a bare-minimum body before giving up.
    let includeExtras = configuration.supportsStructuredOutputs
      || configuration.temperature != nil
      || configuration.maxTokens != nil
    do {
      return try await performStreaming(
        prompt: prompt,
        apiKey: apiKey,
        includeExtras: includeExtras,
        onPartial: onPartial,
        clock: clock,
        requestStart: requestStart
      )
    } catch AIClientError.httpStatus(let code) where includeExtras && (400..<500).contains(code) {
      aiClientLogger.info(
        "AI request got HTTP \(code, privacy: .public) with structured-output params; retrying once without them."
      )
      return try await performStreaming(
        prompt: prompt,
        apiKey: apiKey,
        includeExtras: false,
        onPartial: onPartial,
        clock: clock,
        requestStart: requestStart
      )
    }
  }

  private func performStreaming(
    prompt: String,
    apiKey: String,
    includeExtras: Bool,
    onPartial: @escaping @Sendable (String) -> Void,
    clock: ContinuousClock,
    requestStart: ContinuousClock.Instant
  ) async throws -> String {
    var request = URLRequest(url: configuration.baseURL.appending(path: "chat/completions"))
    request.httpMethod = "POST"
    request.timeoutInterval = configuration.timeoutSeconds
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(ChatCompletionRequest(
      model: configuration.model,
      messages: [RequestMessage(role: "user", content: prompt)],
      stream: true,
      responseFormat: includeExtras && configuration.supportsStructuredOutputs ? .jsonObject : nil,
      temperature: includeExtras ? configuration.temperature : nil,
      maxTokens: includeExtras ? configuration.maxTokens : nil
    ))

    aiClientLogger.info(
      "AI request started; model: \(configuration.model, privacy: .public); endpoint: \(request.url?.absoluteString ?? "Unknown URL", privacy: .public); prompt characters: \(prompt.count, privacy: .public)."
    )

    let lines: AsyncThrowingStream<String, Error>
    let response: HTTPURLResponse
    do {
      (lines, response) = try await httpClient.lines(for: request)
    } catch {
      aiClientLogger.error(
        "AI request failed after \(elapsedMilliseconds(from: requestStart, clock: clock), privacy: .public) ms: \(String(describing: error), privacy: .public)"
      )
      throw error
    }

    guard (200..<300).contains(response.statusCode) else {
      aiClientLogger.error("AI response returned non-success status: \(response.statusCode, privacy: .public).")
      throw AIClientError.httpStatus(response.statusCode)
    }

    var aggregated = ""
    var sawStreamedDelta = false
    var loggedTimeToFirstToken = false
    var bufferedBody = ""
    do {
      for try await line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { continue }
        if trimmed.hasPrefix("data:") {
          let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
          if payload == "[DONE]" { break }
          if let chunk = payload.data(using: .utf8),
             let decoded = try? JSONDecoder().decode(StreamChunk.self, from: chunk),
             let piece = decoded.choices.first?.delta?.content {
            if !loggedTimeToFirstToken {
              loggedTimeToFirstToken = true
              aiClientLogger.info(
                "AI time to first token: \(elapsedMilliseconds(from: requestStart, clock: clock), privacy: .public) ms."
              )
            }
            aggregated += piece
            sawStreamedDelta = true
            onPartial(aggregated)
          }
        } else {
          bufferedBody += line
        }
      }
    } catch {
      aiClientLogger.error(
        "AI response stream failed after \(elapsedMilliseconds(from: requestStart, clock: clock), privacy: .public) ms: \(String(describing: error), privacy: .public)"
      )
      throw error
    }

    // If the request was cancelled (new lookup started, or panel closed), the stream
    // finishes with whatever partial text arrived. Surface it as cancellation instead of
    // returning truncated JSON that would spuriously trigger a repair retry.
    try Task.checkCancellation()

    aiClientLogger.info(
      "AI response received in \(elapsedMilliseconds(from: requestStart, clock: clock), privacy: .public) ms; status: \(response.statusCode, privacy: .public); streamed: \(sawStreamedDelta, privacy: .public)."
    )

    if sawStreamedDelta {
      guard !aggregated.isEmpty else {
        aiClientLogger.error("AI streamed response had empty content.")
        throw AIClientError.emptyContent
      }
      return aggregated
    }

    // Fallback: provider returned a buffered (non-streamed) chat completion.
    do {
      let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: Data(bufferedBody.utf8))
      guard let content = completion.choices.first?.message.content, !content.isEmpty else {
        aiClientLogger.error("AI response decoded with empty content.")
        throw AIClientError.emptyContent
      }
      return content
    } catch let error as AIClientError {
      throw error
    } catch {
      aiClientLogger.error("AI response decoding failed: \(String(describing: error), privacy: .public)")
      throw AIClientError.invalidResponse
    }
  }
}

private struct ChatCompletionRequest: Encodable {
  let model: String
  let messages: [RequestMessage]
  let stream: Bool
  var responseFormat: ResponseFormat?
  var temperature: Double?
  var maxTokens: Int?

  enum CodingKeys: String, CodingKey {
    case model
    case messages
    case stream
    case responseFormat = "response_format"
    case temperature
    case maxTokens = "max_tokens"
  }

  struct ResponseFormat: Encodable {
    let type: String
    static let jsonObject = ResponseFormat(type: "json_object")
  }
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

private struct StreamChunk: Decodable {
  let choices: [StreamChoice]
}

private struct StreamChoice: Decodable {
  let delta: StreamDelta?
}

private struct StreamDelta: Decodable {
  let content: String?
}
