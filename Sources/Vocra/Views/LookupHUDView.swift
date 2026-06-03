import SwiftUI
import VocraCore

/// Shared, observable progress for the floating lookup HUD. Updated live as the
/// model streams so the small window can show "content edge-out" feedback.
@MainActor
@Observable
final class LookupProgress {
  var term: String = ""
  var mode: ExplanationMode = .word
  var preview: String = ""

  func reset(term: String, mode: ExplanationMode) {
    self.term = term
    self.mode = mode
    self.preview = ""
  }
}

/// Compact, non-blocking HUD shown while a lookup is being fetched/parsed. It
/// floats over the user's current app and expands into the full result panel.
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
    HStack(spacing: 13) {
      ZStack {
        Circle().fill(VocraTheme.accentSoft).frame(width: 38, height: 38)
        ProgressView()
          .controlSize(.small)
          .tint(VocraTheme.accent)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 0) {
          Text("正在\(modeLabel)")
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(VocraTheme.ink900)
          if !progress.term.isEmpty {
            Text(" 「\(progress.term)」")
              .font(.system(size: 13.5, weight: .semibold))
              .foregroundStyle(VocraTheme.accentInk)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
        Text(progress.preview.isEmpty ? "已识别，正在获取并解析…" : progress.preview)
          .font(.system(size: 11.5))
          .foregroundStyle(VocraTheme.ink500)
          .lineLimit(2)
          .frame(height: 30, alignment: .topLeading)
          .animation(.easeOut(duration: 0.18), value: progress.preview)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .frame(width: LookupHUDView.size.width, height: LookupHUDView.size.height, alignment: .leading)
    .vocraFloatingGlass(cornerRadius: 18)
    .environment(\.colorScheme, .light)
  }

  static let size = CGSize(width: 380, height: 86)
}
