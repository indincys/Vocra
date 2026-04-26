import Foundation

public protocol AIClient: Sendable {
  func complete(prompt: String) async throws -> String
}

public enum AIClientError: Error, Equatable, Sendable {
  case missingAPIKey
  case invalidResponse
  case httpStatus(Int)
  case emptyContent
}
