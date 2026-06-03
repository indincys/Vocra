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
}
