import Foundation

public struct LearningExplanationSummaryRenderer: Sendable {
  public init() {}

  public func render(_ document: LearningExplanationDocument) -> String {
    if let vocabularyCard = document.vocabularyCard {
      return renderVocabularyCard(vocabularyCard, sourceText: document.sourceText)
    }

    return switch document.mode {
    case .sentence:
      renderSentence(document)
    case .word, .phrase:
      renderWord(document)
    }
  }

  private func renderSentence(_ document: LearningExplanationDocument) -> String {
    guard let analysis = document.sentenceAnalysis else { return document.sourceText }
    return [
      document.sourceText,
      analysis.translation.text,
      analysis.logicSummary.coreMeaning,
      analysis.logicSummary.points.joined(separator: "\n")
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")
  }

  private func renderWord(_ document: LearningExplanationDocument) -> String {
    guard let word = document.wordExplanation else { return document.sourceText }
    return [
      word.term,
      word.coreMeaning,
      word.contextualMeaning,
      word.usageNotes.joined(separator: "\n")
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")
  }

  private func renderVocabularyCard(_ card: StructuredVocabularyCard, sourceText: String) -> String {
    [
      sourceText,
      card.front.text,
      card.front.hint ?? "",
      card.back.coreMeaning,
      card.back.memoryNote,
      card.back.usage,
      card.examples.map { [$0.sentence, $0.translation].joined(separator: "\n") }.joined(separator: "\n\n"),
      card.reviewPrompts.joined(separator: "\n")
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")
  }
}
