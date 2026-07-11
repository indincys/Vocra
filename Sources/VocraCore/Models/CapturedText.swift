import Foundation

public struct CapturedText: Equatable, Sendable {
  public let originalText: String
  public let cleanedText: String
  public let mode: ExplanationMode
  public let sourceApp: String?
  /// Text surrounding the selection (with the selection embedded), used only to help the
  /// model disambiguate meaning. Empty when unavailable (e.g. clipboard fallback).
  public let surroundingContext: String

  public init(
    originalText: String,
    cleanedText: String,
    mode: ExplanationMode,
    sourceApp: String? = nil,
    surroundingContext: String = ""
  ) {
    self.originalText = originalText
    self.cleanedText = cleanedText
    self.mode = mode
    self.sourceApp = sourceApp
    self.surroundingContext = surroundingContext
  }
}
