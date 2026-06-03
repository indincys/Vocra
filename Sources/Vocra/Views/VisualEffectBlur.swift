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

/// Reaches the hosting `NSWindow` to configure it (e.g. make it translucent so
/// behind-window materials frost the desktop).
struct WindowConfigurator: NSViewRepresentable {
  let configure: (NSWindow) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async { [weak view] in
      if let window = view?.window { configure(window) }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async { [weak nsView] in
      if let window = nsView?.window { configure(window) }
    }
  }
}

extension View {
  /// Refined macOS Liquid Glass for floating windows: behind-window vibrancy +
  /// a frosted top-lit sheen, a crisp gradient edge, and layered depth shadows.
  func vocraFloatingGlass(cornerRadius: CGFloat = 24) -> some View {
    modifier(VocraFloatingGlass(cornerRadius: cornerRadius))
  }
}

private struct VocraFloatingGlass: ViewModifier {
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .background {
        // Light top-lit sheen over the live blur — kept subtle so the glass
        // stays clearly see-through.
        shape.fill(
          LinearGradient(
            colors: [Color.white.opacity(0.22), Color.white.opacity(0.06), Color.white.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      }
      .background {
        VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
      }
      .clipShape(shape)
      .overlay {
        // Bright inner top edge → soft lower edge: the liquid-glass rim.
        shape.strokeBorder(
          LinearGradient(
            colors: [Color.white.opacity(0.85), Color.white.opacity(0.30), Color.white.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
      }
      .overlay {
        shape.strokeBorder(VocraTheme.hairline, lineWidth: 0.5)
      }
  }
}
