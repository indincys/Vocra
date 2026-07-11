import AppKit
import Carbon
import SwiftUI
import VocraCore

@MainActor
final class FloatingPanelController: ExplanationPanelPresenting {
  private var panel: NSPanel?
  /// A single reused hosting view. Reassigning its `rootView` (rather than creating a new
  /// NSHostingView on every `show`) preserves SwiftUI @State and scroll position across
  /// progressive result updates, avoiding visual flashes as streamed content fills in.
  private var hostingView: NSHostingView<AnyView>?
  private var localEscapeMonitor: Any?
  private var globalEscapeMonitor: Any?
  private var globalClickMonitor: Any?
  private let progress = LookupProgress()
  private var isShowingHUD = false
  /// True while the full result/error panel is on screen — gates click-outside
  /// dismissal so a stray click during the transient loading HUD can't cancel it.
  private var isShowingResult = false
  /// Latest dismissal handler from `show`. Esc / click-outside route through this so the
  /// in-flight lookup gets cancelled, not just visually hidden.
  private var onCloseHandler: (() -> Void)?
  private static let resultSize = CGSize(width: 540, height: 660)

  func show(
    content: ExplanationPanelContent,
    onSwitchMode: @escaping (ExplanationMode) -> Void,
    onSaveVocabulary: @escaping VocabularySaveAction,
    onClose: @escaping () -> Void
  ) {
    onCloseHandler = onClose
    let isLoading = content.document == nil && content.errorMessage == nil && content.validationErrorMessage == nil
    if isLoading {
      presentLoadingHUD(
        term: content.capturedText?.cleanedText ?? "",
        mode: content.capturedText?.mode ?? .word
      )
    } else {
      presentResult(rootView: ExplanationPanelView(
        capturedText: content.capturedText,
        document: content.document,
        errorMessage: content.errorMessage,
        errorRecovery: content.errorRecovery,
        validationErrorMessage: content.validationErrorMessage,
        onSwitchMode: onSwitchMode,
        onSaveVocabulary: onSaveVocabulary,
        onClose: onClose
      ))
    }
  }

  func close() {
    isShowingResult = false
    panel?.orderOut(nil)
  }

  func updateProgress(receivedCharacters: Int) {
    // Only meaningful while the HUD is up; once the result is shown the bar is gone.
    guard isShowingHUD else { return }
    progress.receivedCharacters = receivedCharacters
  }

  /// User-initiated dismissal (Esc / click-outside). Prefers the `onClose` handler so the
  /// owning model can cancel the in-flight request; falls back to a plain hide.
  private func dismiss() {
    if let onCloseHandler {
      onCloseHandler()
    } else {
      close()
    }
  }

  // MARK: Presentation

  private func presentLoadingHUD(term: String, mode: ExplanationMode) {
    let panel = existingOrCreatePanel()
    progress.reset(term: term, mode: mode)
    isShowingResult = false
    if !isShowingHUD {
      isShowingHUD = true
      setRootView(LookupHUDView(progress: progress))
      panel.setFrame(bottomRightFrame(size: LookupHUDView.size), display: true, animate: false)
    }
    panel.orderFrontRegardless()
  }

  private func presentResult<Content: View>(rootView: Content) {
    let panel = existingOrCreatePanel()
    setRootView(rootView)
    isShowingResult = true
    if isShowingHUD {
      isShowingHUD = false
      // Grow up-and-left from the HUD's bottom-right corner into the result.
      panel.setFrame(bottomRightFrame(size: Self.resultSize), display: true, animate: true)
    }
    // Float above the frontmost app WITHOUT activating Vocra or taking key
    // focus, so the user can keep working. Dismiss via the global Esc monitor.
    panel.orderFrontRegardless()
  }

  /// Reuses the single hosting view, updating its root instead of replacing the view.
  private func setRootView(_ view: some View) {
    let erased = AnyView(view)
    if let hostingView {
      hostingView.rootView = erased
    } else {
      let hostingView = NSHostingView(rootView: erased)
      self.hostingView = hostingView
      panel?.contentView = hostingView
    }
  }

  /// Anchors a window of the given size to the bottom-right of the active screen.
  private func bottomRightFrame(size: CGSize) -> NSRect {
    let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let margin: CGFloat = 22
    return NSRect(
      x: visible.maxX - size.width - margin,
      y: visible.minY + margin,
      width: size.width,
      height: size.height
    )
  }

  private func existingOrCreatePanel() -> NSPanel {
    if let panel { return panel }

    let panel = EscapeClosingPanel(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 660),
      styleMask: [.borderless, .resizable, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.minSize = NSSize(width: 380, height: 86)
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = true
    panel.onEscape = { [weak self] in
      self?.dismiss()
    }
    panel.center()
    self.panel = panel
    installEscapeMonitor(for: panel)
    return panel
  }

  private func installEscapeMonitor(for panel: NSPanel) {
    guard localEscapeMonitor == nil, globalEscapeMonitor == nil else { return }
    localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
      guard Int(event.keyCode) == kVK_Escape, panel?.isVisible == true else {
        return event
      }

      self?.dismiss()
      return nil
    }

    globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
      guard Int(event.keyCode) == kVK_Escape, panel?.isVisible == true else {
        return
      }

      Task { @MainActor in
        self?.dismiss()
      }
    }

    // Clicking outside the result panel dismisses it. A global monitor only
    // fires for events delivered to OTHER apps/windows, so any click it sees is
    // necessarily outside our panel; clicks inside the panel never reach here.
    globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] _ in
      guard panel?.isVisible == true else { return }
      Task { @MainActor in
        guard let self, self.isShowingResult else { return }
        self.dismiss()
      }
    }
  }
}

final class EscapeClosingPanel: NSPanel {
  var onEscape: (() -> Void)?

  override func cancelOperation(_ sender: Any?) {
    onEscape?()
  }

  override func keyDown(with event: NSEvent) {
    guard Int(event.keyCode) == kVK_Escape else {
      super.keyDown(with: event)
      return
    }

    onEscape?()
  }
}
