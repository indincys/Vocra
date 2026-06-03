import SwiftUI
import VocraCore

/// Glass sheet that re-presents a saved card's stored explanation when a row is
/// tapped in Today or the vocabulary book.
struct CardDetailSheet: View {
  let card: VocabularyCard
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
          Text(card.text)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(VocraTheme.ink900)
            .lineLimit(1)
          if let pronunciation = card.displayPronunciation {
            Text(pronunciation)
              .font(.system(size: 13, design: .monospaced))
              .foregroundStyle(VocraTheme.ink500)
          }
        }
        SpeakerButton(text: card.text)
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VocraTheme.ink500)
            .frame(width: 30, height: 30)
            .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .background(Color.white.opacity(0.6))
      .overlay(alignment: .bottom) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }

      ScrollView {
        Group {
          if let document = card.decodedDocument {
            LearningExplanationView(document: document)
          } else {
            Text("无法解析这张卡片的内容。")
              .font(.callout)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(18)
          }
        }
        .padding(.bottom, 8)
      }
      .scrollContentBackground(.hidden)
    }
    .frame(width: 640, height: 660)
    .background(.regularMaterial)
    .environment(\.colorScheme, .light)
  }
}
