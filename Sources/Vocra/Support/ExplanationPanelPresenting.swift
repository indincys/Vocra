import VocraCore

struct ExplanationPanelContent: Equatable {
  let capturedText: CapturedText?
  let markdown: String
  let errorMessage: String?
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
