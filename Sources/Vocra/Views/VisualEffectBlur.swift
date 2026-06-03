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
        // Frosted, top-lit sheen sitting over the live blur.
        shape.fill(
          LinearGradient(
            colors: [Color.white.opacity(0.42), Color.white.opacity(0.16), Color.white.opacity(0.10)],
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
