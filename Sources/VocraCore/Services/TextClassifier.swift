import Foundation

public struct TextClassifier: Sendable {
  private let predicateMarkers: Set<String> = [
    "is", "are", "was", "were", "be", "been",
    "has", "have", "had",
    "can", "could", "should", "would", "will",
    "returns", "returned", "failed", "fails", "means", "refers"
  ]

  public init() {}

  public func classify(_ text: String, sourceApp: String? = nil) -> CapturedText {
    let cleaned = clean(text)
    let mode = classifyCleanedText(cleaned)
    return CapturedText(originalText: text, cleanedText: cleaned, mode: mode, sourceApp: sourceApp)
  }

  public func clean(_ text: String) -> String {
    let collapsed = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    let edgeCharacters = CharacterSet(charactersIn: "\"'`“”‘’()[]{}")
    return collapsed.trimmingCharacters(in: edgeCharacters)
  }

  private func classifyCleanedText(_ text: String) -> ExplanationMode {
    guard !text.isEmpty else { return .sentence }

    let words = text.split(separator: " ").map(String.init)
    let spaceCount = max(words.count - 1, 0)

    if spaceCount == 0 { return .word }
    if spaceCount == 1 { return .phrase }

    if hasSentencePunctuation(text) { return .sentence }
    if hasPredicateMarker(words) { return .sentence }
    if words.count <= 5 { return .phrase }

    return .sentence
  }

  private func hasSentencePunctuation(_ text: String) -> Bool {
    text.contains { character in
      ".?!;:".contains(character)
    }
  }

  private func hasPredicateMarker(_ words: [String]) -> Bool {
    words.contains { word in
      let normalized = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
      return predicateMarkers.contains(normalized)
    }
  }
}
