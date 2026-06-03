import Foundation

public protocol AIClient: Sendable {
  func complete(prompt: String) async throws -> String
  /// Same as `complete`, but invokes `onPartial` with the accumulated content as
  /// it streams, so callers can show progress. The returned string is the full
  /// content.
  func complete(prompt: String, onPartial: @escaping @Sendable (String) -> Void) async throws -> String
}

public extension AIClient {
  func complete(prompt: String, onPartial: @escaping @Sendable (String) -> Void) async throws -> String {
    try await complete(prompt: prompt)
  }
}

public enum AIClientError: Error, Equatable, Sendable {
  case missingAPIKey
  case invalidResponse
  case httpStatus(Int)
  case emptyContent
}
