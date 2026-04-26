import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
  private var panel: NSPanel?
  private let autosaveName = "VocraExplanationPanelFrame"

  func show<Content: View>(rootView: Content) {
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

    let panel = NSPanel(
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
    panel.center()
    self.panel = panel
    return panel
  }
}
