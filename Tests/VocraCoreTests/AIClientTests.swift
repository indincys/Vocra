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
      temperature: 0.3,
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
  }
}

private final class StubHTTPClient: HTTPClient, @unchecked Sendable {
  var lastRequest: URLRequest?
  let responseData: Data

  init(responseData: Data) {
    self.responseData = responseData
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    lastRequest = request
    return (
      responseData,
      HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    )
  }
}
