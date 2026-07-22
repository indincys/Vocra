import VocraCore

struct ExplanationPanelContent: Equatable {
  let capturedText: CapturedText?
  let document: LearningExplanationDocument?
  let errorMessage: String?
  var errorRecovery: LookupErrorRecovery? = nil
  let validationErrorMessage: String?
}

/// Saves a term to the vocabulary book: (text, type, backing document).
typealias VocabularySaveAction = (String, VocabularyType, LearningExplanationDocument) -> Void

/// A transient confirmation shown in place of a lookup result — e.g. "已收录到阅读区".
struct PanelNotice: Equatable {
  let symbolName: String
  let title: String
  let subtitle: String
}

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
  /// Flashes a short confirmation that dismisses itself.
  func presentNotice(_ notice: PanelNotice)
}

extension ExplanationPanelPresenting {
  func updateProgress(receivedCharacters: Int) {}
  func presentNotice(_ notice: PanelNotice) {}
}
