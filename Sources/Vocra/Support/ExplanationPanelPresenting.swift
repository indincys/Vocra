import VocraCore

struct ExplanationPanelContent: Equatable {
  let capturedText: CapturedText?
  let document: LearningExplanationDocument?
  let errorMessage: String?
  let validationErrorMessage: String?
}

/// Saves a term to the vocabulary book: (text, type, backing document).
typealias VocabularySaveAction = (String, VocabularyType, LearningExplanationDocument) -> Void

@MainActor
protocol ExplanationPanelPresenting: AnyObject {
  func show(
    content: ExplanationPanelContent,
    onSwitchMode: @escaping (ExplanationMode) -> Void,
    onSaveVocabulary: @escaping VocabularySaveAction,
    onClose: @escaping () -> Void
  )
  func close()
  /// Feeds the number of characters streamed so far to the loading HUD, so its progress
  /// reflects real activity instead of a pure indeterminate animation.
  func updateProgress(receivedCharacters: Int)
}

extension ExplanationPanelPresenting {
  func updateProgress(receivedCharacters: Int) {}
}
