import Foundation

public struct CapturedText: Equatable, Sendable {
  public let originalText: String
  public let cleanedText: String
  public let mode: ExplanationMode
  public let sourceApp: String?

  public init(originalText: String, cleanedText: String, mode: ExplanationMode, sourceApp: String? = nil) {
    self.originalText = originalText
    self.cleanedText = cleanedText
    self.mode = mode
    self.sourceApp = sourceApp
  }
}
