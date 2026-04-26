import Foundation

public enum ExplanationMode: String, CaseIterable, Codable, Equatable, Sendable {
  case word
  case phrase
  case sentence

  public var displayName: String {
    switch self {
    case .word: "Word"
    case .phrase: "Term"
    case .sentence: "Sentence"
    }
  }
}
