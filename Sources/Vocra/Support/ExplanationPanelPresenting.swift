import VocraCore

struct ExplanationPanelContent: Equatable {
  let capturedText: CapturedText?
  let document: LearningExplanationDocument?
  let errorMessage: String?
  let validationErrorMessage: String?
}

@MainActor
protocol ExplanationPanelPresenting: AnyObject {
  func show(
    content: ExplanationPanelContent,
    onSwitchMode: @escaping (ExplanationMode) -> Void,
    onClose: @escaping () -> Void
  )
  func close()
}
