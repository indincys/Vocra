import AppKit
import Carbon
import SwiftUI
import VocraCore

@MainActor
final class FloatingPanelController: ExplanationPanelPresenting {
  private var panel: NSPanel?
  private var localEscapeMonitor: Any?
  private var globalEscapeMonitor: Any?
  private let autosaveName = "VocraExplanationPanelFrame"

  func show(
    content: ExplanationPanelContent,
    onSwitchMode: @escaping (ExplanationMode) -> Void,
    onClose: @escaping () -> Void
  ) {
    present(rootView: ExplanationPanelView(
      capturedText: content.capturedText,
      markdown: content.markdown,
      errorMessage: content.errorMessage,
      onSwitchMode: onSwitchMode,
      onClose: onClose
    ))
  }

  private func present<Content: View>(rootView: Content) {
    let panel = existingOrCreatePanel()
    panel.contentView = NSHostingView(rootView: rootView)
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    panel?.orderOut(nil)
  }

  private func existingOrCreatePanel() -> NSPanel {
    if let panel { return panel }

    let panel = EscapeClosingPanel(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
      styleMask: [.borderless, .resizable, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.minSize = NSSize(width: 480, height: 520)
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = true
    panel.setFrameAutosaveName(autosaveName)
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
