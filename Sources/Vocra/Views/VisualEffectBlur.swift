import AppKit
import SwiftUI

/// Bridges `NSVisualEffectView` so the sidebar picks up authentic macOS
/// behind-window vibrancy (the Liquid Glass base layer).
struct VisualEffectBlur: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .sidebar
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.state = .active
  }
}
