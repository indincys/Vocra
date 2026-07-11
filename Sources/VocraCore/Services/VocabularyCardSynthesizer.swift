import Foundation

/// Builds a vocabulary review card locally from an already-generated `WordExplanation`,
/// avoiding a second model round-trip. The card's core meaning, usage, and examples are
/// nearly identical to the word explanation, so synthesizing them locally is free and
/// instant instead of paying for another full generation.
public enum VocabularyCardSynthesizer {
  /// Returns a card document derived from `document.wordExplanation`, or `nil` if the
  /// document has no word explanation to map from.
  public static func card(from document: LearningExplanationDocument, captured: CapturedText) -> LearningExplanationDocument? {
    guard let word = document.wordExplanation else { return nil }

    let term = firstNonEmpty(word.term, captured.cleanedText)
    let usage = firstNonEmpty(
      word.usageNotes.map(trimmed).filter { !$0.isEmpty }.joined(separator: "\n"),
      word.collocations.map(trimmed).filter { !$0.isEmpty }.joined(separator: "、"),
      word.contextualMeaning,
      word.coreMeaning
    )
    let memoryNote = firstNonEmpty(word.contextualMeaning, word.coreMeaning, usage)

    let examples = word.examples
      .filter { !trimmed($0.sentence).isEmpty && !trimmed($0.translation).isEmpty }
      .map { VocabularyCardExample(sentence: $0.sentence, translation: $0.translation) }

    let card = StructuredVocabularyCard(
      front: VocabularyCardFront(text: term, hint: nonEmptyOrNil(word.partOfSpeech)),
      back: VocabularyCardBack(
        coreMeaning: firstNonEmpty(word.coreMeaning, term),
        memoryNote: memoryNote,
        usage: usage
      ),
      examples: examples,
      reviewPrompts: []
    )

    return LearningExplanationDocument(
      schemaVersion: LearningExplanationDocument.currentSchemaVersion,
      mode: captured.mode,
      sourceText: captured.cleanedText,
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: nil,
      wordExplanation: nil,
      vocabularyCard: card,
      warnings: []
    )
  }

  private static func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func nonEmptyOrNil(_ text: String) -> String? {
    let value = trimmed(text)
    return value.isEmpty ? nil : value
  }

  /// Returns the first candidate that is non-empty after trimming, or the last candidate
  /// as a final fallback (so callers always get a value).
  private static func firstNonEmpty(_ candidates: String...) -> String {
    for candidate in candidates where !trimmed(candidate).isEmpty {
      return candidate
    }
    return candidates.last ?? ""
  }
}
