import AppKit
import Carbon
import SwiftUI
import VocraCore

@MainActor
final class FloatingPanelController: ExplanationPanelPresenting {
  private var panel: NSPanel?
  private var localEscapeMonitor: Any?
  private var globalEscapeMonitor: Any?
  private let progress = LookupProgress()
  private var isShowingHUD = false
  private var resultFrame: NSRect?

  func show(
    content: ExplanationPanelContent,
    onSwitchMode: @escaping (ExplanationMode) -> Void,
    onSaveVocabulary: @escaping VocabularySaveAction,
    onClose: @escaping () -> Void
  ) {
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
        validationErrorMessage: content.validationErrorMessage,
        onSwitchMode: onSwitchMode,
        onSaveVocabulary: onSaveVocabulary,
        onClose: onClose
      ))
    }
  }

  func updateStreamingPreview(_ text: String) {
    progress.preview = text
  }

  func close() {
    panel?.orderOut(nil)
  }

  // MARK: Presentation

  private func presentLoadingHUD(term: String, mode: ExplanationMode) {
    let panel = existingOrCreatePanel()
    progress.reset(term: term, mode: mode)
    if !isShowingHUD {
      // Remember where the full result should appear, then shrink to the HUD.
      resultFrame = panel.frame
      isShowingHUD = true
      panel.contentView = NSHostingView(rootView: LookupHUDView(progress: progress))
      panel.setFrame(hudFrame(centeredOn: panel.frame), display: true, animate: false)
    }
    panel.orderFrontRegardless()
  }

  private func presentResult<Content: View>(rootView: Content) {
    let panel = existingOrCreatePanel()
    panel.contentView = NSHostingView(rootView: rootView)
    if isShowingHUD {
      isShowingHUD = false
      let target = resultFrame ?? panel.frame
      panel.setFrame(target, display: true, animate: true)
    }
    // Float above the frontmost app WITHOUT activating Vocra or taking key
    // focus, so the user can keep working. Dismiss via the global Esc monitor.
    panel.orderFrontRegardless()
  }

  private func hudFrame(centeredOn frame: NSRect) -> NSRect {
    let size = LookupHUDView.size
    return NSRect(
      x: frame.midX - size.width / 2,
      y: frame.midY - size.height / 2,
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
    panel.appearance = NSAppearance(named: .aqua)
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = true
    panel.onEscape = { [weak self] in
      self?.close()
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

      self?.close()
      return nil
    }

    globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
      guard Int(event.keyCode) == kVK_Escape, panel?.isVisible == true else {
        return
      }

      Task { @MainActor in
        self?.close()
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
