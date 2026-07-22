import AppKit
import SwiftUI

/// The small self-dismissing toast in the bottom-right corner — currently only used to confirm
/// that a selection was collected into the reading section.
///
/// It is a non-activating panel on purpose: the collect shortcut is pressed while the user is
/// reading in another app, so the confirmation must never take focus or raise Vocra. Lookup
/// results do **not** come through here any more; they render in the main window (see
/// `MainWindowLookupPresenter`).
@MainActor
final class NoticeToastController {
  private var panel: NSPanel?
  /// A single reused hosting view: reassigning `rootView` avoids rebuilding the view tree
  /// (and re-running its entry animation) for each toast.
  private var hostingView: NSHostingView<AnyView>?
  private var dismissalTask: Task<Void, Never>?

  func present(_ notice: PanelNotice) {
    let panel = existingOrCreatePanel()
    setRootView(PanelNoticeView(notice: notice))
    panel.setFrame(bottomRightFrame(size: PanelNoticeView.size), display: true, animate: false)
    panel.orderFrontRegardless()

    dismissalTask?.cancel()
    dismissalTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(2.2))
      guard !Task.isCancelled else { return }
      self?.close()
    }
  }

  func close() {
    dismissalTask?.cancel()
    dismissalTask = nil
    panel?.orderOut(nil)
  }

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

  /// Anchors the toast to the bottom-right of the active screen.
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

    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: PanelNoticeView.size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    // Purely informational, and it sits over whatever the user was reading — clicks must
    // pass straight through to the app underneath.
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.panel = panel
    return panel
  }
}
