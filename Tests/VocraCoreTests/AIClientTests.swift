import Foundation
import XCTest
@testable import VocraCore

final class AIClientTests: XCTestCase {
  func testBuildsChatCompletionRequestAndParsesContent() async throws {
    let http = StubHTTPClient(responseData: Data("""
    {"choices":[{"message":{"content":"## Meaning\\nA vector representation."}}]}
    """.utf8))
    let configuration = APIConfiguration(
      baseURL: URL(string: "https://example.com/v1")!,
      model: "model-a",
      timeoutSeconds: 10
    )
    let client = OpenAICompatibleClient(
      configuration: configuration,
      apiKeyProvider: { "secret" },
      httpClient: http
    )

    let content = try await client.complete(prompt: "Explain embedding")

    XCTAssertEqual(content, "## Meaning\nA vector representation.")
    XCTAssertEqual(http.lastRequest?.url?.absoluteString, "https://example.com/v1/chat/completions")
    XCTAssertEqual(http.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
    let body = try XCTUnwrap(http.lastJSONBody)
    XCTAssertEqual(body["model"] as? String, "model-a")
    XCTAssertNil(body["temperature"])
  }

  func testAggregatesStreamedDeltaChunksAndRequestsStreaming() async throws {
    let http = StreamingStubHTTPClient(lines: [
      "data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}",
      "",
      "data: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}",
      "data: [DONE]",
    ])
    let configuration = APIConfiguration(
      baseURL: URL(string: "https://example.com/v1")!,
      model: "model-a",
      timeoutSeconds: 10
    )
    let client = OpenAICompatibleClient(
      configuration: configuration,
      apiKeyProvider: { "secret" },
      httpClient: http
    )

    let content = try await client.complete(prompt: "Say hello")

    XCTAssertEqual(content, "Hello")
    XCTAssertEqual(http.lastJSONBody?["stream"] as? Bool, true)
    XCTAssertEqual(http.lastJSONBody?["model"] as? String, "model-a")
  }

  func testAPIConnectionTesterUsesProvidedConfigurationAndAPIKey() async throws {
    let http = StubHTTPClient(responseData: Data("""
    {"choices":[{"message":{"content":"OK"}}]}
    """.utf8))
    let configuration = APIConfiguration(
      baseURL: URL(string: "https://example.com/v1")!,
      model: "model-a",
      timeoutSeconds: 10
    )

    try await APIConnectionTester(httpClient: http).test(configuration: configuration, apiKey: "secret")

    XCTAssertEqual(http.lastRequest?.url?.absoluteString, "https://example.com/v1/chat/completions")
    XCTAssertEqual(http.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
    let body = try XCTUnwrap(http.lastJSONBody)
    XCTAssertEqual(body["model"] as? String, "model-a")
  }
}

private final class StubHTTPClient: HTTPClient, @unchecked Sendable {
  var lastRequest: URLRequest?
  let responseData: Data
  var statusCode = 200

  init(responseData: Data) {
    self.responseData = responseData
  }

  var lastJSONBody: [String: Any]? {
    guard let data = lastRequest?.httpBody else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    lastRequest = request
    return (
      responseData,
      HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    )
  }
}

private final class StreamingStubHTTPClient: HTTPClient, @unchecked Sendable {
  var lastRequest: URLRequest?
  let lines: [String]
  var statusCode = 200

  init(lines: [String]) {
    self.lines = lines
  }

  var lastJSONBody: [String: Any]? {
    guard let data = lastRequest?.httpBody else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    lastRequest = request
    return (Data(), HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
  }

  func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, HTTPURLResponse) {
    lastRequest = request
    let payload = lines
    let stream = AsyncThrowingStream<String, Error> { continuation in
      for line in payload { continuation.yield(line) }
      continuation.finish()
    }
    return (stream, HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
  }
}
