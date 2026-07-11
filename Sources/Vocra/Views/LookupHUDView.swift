import SwiftUI
import VocraCore

/// Lightweight, observable state for the floating lookup HUD.
@MainActor
@Observable
final class LookupProgress {
  var term: String = ""
  var mode: ExplanationMode = .word
  /// Characters streamed from the model so far. Drives a determinate-ish progress bar.
  var receivedCharacters: Int = 0

  func reset(term: String, mode: ExplanationMode) {
    self.term = term
    self.mode = mode
    self.receivedCharacters = 0
  }

  /// A rough 0–0.95 fraction from the streamed character count against a typical response
  /// length. Never reaches 1.0 — completion is signalled by swapping to the result panel.
  var fraction: Double {
    guard receivedCharacters > 0 else { return 0 }
    let typicalLength = mode == .sentence ? 900.0 : 500.0
    return min(0.95, Double(receivedCharacters) / typicalLength)
  }
}

/// Tiny, silent progress HUD shown in the bottom-right corner while a lookup is
/// fetched/parsed. It floats over the user's app without stealing focus, then
/// expands into the full result panel.
struct LookupHUDView: View {
  @Bindable var progress: LookupProgress

  private var modeLabel: String {
    switch progress.mode {
    case .sentence: "解析句子"
    case .phrase: "解析词组"
    case .word: "解析单词"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 9) {
        Image(systemName: "square.stack.3d.up.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(VocraTheme.accent)
          .symbolEffect(.pulse, options: .repeating)
        HStack(spacing: 0) {
          Text("正在\(modeLabel)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VocraTheme.ink900)
          if !progress.term.isEmpty {
            Text(" 「\(progress.term)」")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(VocraTheme.accentInk)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
        Spacer(minLength: 0)
      }
      if progress.fraction > 0 {
        DeterminateBar(fraction: progress.fraction)
      } else {
        IndeterminateBar()
      }
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 12)
    .frame(width: LookupHUDView.size.width, height: LookupHUDView.size.height, alignment: .leading)
    .vocraFloatingGlass(cornerRadius: 16)
    .environment(\.colorScheme, .light)
  }

  static let size = CGSize(width: 300, height: 60)
}

/// A real progress bar filled to `fraction`, animating smoothly as more tokens stream in.
private struct DeterminateBar: View {
  let fraction: Double

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      ZStack(alignment: .leading) {
        Capsule().fill(VocraTheme.fillStrong)
        Capsule()
          .fill(LinearGradient(colors: [VocraTheme.accent.opacity(0.45), VocraTheme.accent], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(6, width * fraction))
          .animation(.easeOut(duration: 0.25), value: fraction)
      }
    }
    .frame(height: 3.5)
  }
}

/// A gently bouncing accent segment — a clear-but-quiet indeterminate progress.
private struct IndeterminateBar: View {
  @State private var animate = false

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let segment = max(44, width * 0.34)
      ZStack(alignment: .leading) {
        Capsule().fill(VocraTheme.fillStrong)
        Capsule()
          .fill(LinearGradient(colors: [VocraTheme.accent.opacity(0.45), VocraTheme.accent], startPoint: .leading, endPoint: .trailing))
          .frame(width: segment)
          .offset(x: animate ? width - segment : 0)
      }
      .onAppear {
        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
          animate = true
        }
      }
    }
    .frame(height: 3.5)
  }
}
