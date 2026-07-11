import Foundation

public struct TextClassifier: Sendable {
  private let predicateMarkers: Set<String> = [
    "is", "are", "was", "were", "be", "been",
    "has", "have", "had",
    "can", "could", "should", "would", "will",
    "returns", "returned", "failed", "fails", "means", "refers"
  ]

  public init() {}

  public func classify(_ text: String, sourceApp: String? = nil, surroundingContext: String = "") -> CapturedText {
    let hadLineBreak = text.contains { character in
      character.isNewline
    }
    let cleaned = clean(text)
    let mode = classifyCleanedText(cleaned, hadLineBreak: hadLineBreak)
    // For a word/phrase, strip edge punctuation (e.g. the comma in "however,") so the
    // panel title, TTS, cache key, and notebook dedup all see the bare term. Sentences
    // keep their punctuation — classification above depends on it.
    let finalText = (mode == .word || mode == .phrase) ? trimmingEdgePunctuation(cleaned) : cleaned
    return CapturedText(
      originalText: text,
      cleanedText: finalText,
      mode: mode,
      sourceApp: sourceApp,
      surroundingContext: surroundingContext
    )
  }

  private func trimmingEdgePunctuation(_ text: String) -> String {
    let punctuation = CharacterSet(charactersIn: ".,;:!?…-–—、，。；：！？·")
    let trimmed = text.trimmingCharacters(in: punctuation)
    // Never trim the term away entirely (e.g. a lone "?!"); fall back to the input.
    return trimmed.isEmpty ? text : trimmed
  }

  public func clean(_ text: String) -> String {
    let collapsed = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    let edgeCharacters = CharacterSet(charactersIn: "\"'`“”‘’")
    return collapsed.trimmingCharacters(in: edgeCharacters)
  }

  private func classifyCleanedText(_ text: String, hadLineBreak: Bool) -> ExplanationMode {
    guard !text.isEmpty else { return .sentence }

    let words = text.split(separator: " ").map(String.init)
    let spaceCount = max(words.count - 1, 0)

    if spaceCount == 0 { return .word }
    if hadLineBreak { return .sentence }
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
