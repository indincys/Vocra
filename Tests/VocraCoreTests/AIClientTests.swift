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
