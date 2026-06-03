import SwiftUI
import VocraCore

struct VocabularyCardLearningView: View {
  let card: StructuredVocabularyCard

  var body: some View {
    VStack(spacing: 0) {
      header
      if !card.examples.isEmpty {
        PopSection(icon: "quote.bubble", title: "例句复习") {
          VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(card.examples.enumerated()), id: \.offset) { _, example in
              VStack(alignment: .leading, spacing: 2) {
                Text(example.sentence)
                  .font(.system(size: 14))
                  .foregroundStyle(VocraTheme.ink900)
                  .lineSpacing(2)
                Text(example.translation)
                  .font(.system(size: 13))
                  .foregroundStyle(VocraTheme.ink500)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
      if !card.reviewPrompts.isEmpty {
        PopSection(icon: "questionmark.circle", title: "复习问题") {
          VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(card.reviewPrompts.enumerated()), id: \.offset) { index, prompt in
              HStack(alignment: .top, spacing: 11) {
                PopNumber(number: index + 1, color: VocraTheme.roleTransition)
                Text(prompt)
                  .font(.system(size: 13.5))
                  .foregroundStyle(VocraTheme.ink700)
                  .lineSpacing(2)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .textSelection(.enabled)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 9) {
        Text(card.front.text)
          .font(.system(size: 25, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
        if let hint = card.front.hint, !hint.isEmpty {
          VocraChip(text: hint, tint: VocraTheme.accentInk)
        }
        Spacer(minLength: 0)
        SpeakerButton(text: card.front.text, size: 15)
      }

      VStack(spacing: 8) {
        backField(label: "核心释义", text: card.back.coreMeaning, color: VocraTheme.roleSubject, ink: VocraTheme.roleSubjectInk)
        backField(label: "记忆提示", text: card.back.memoryNote, color: VocraTheme.roleObject, ink: VocraTheme.roleObjectInk)
        backField(label: "使用场景", text: card.back.usage, color: VocraTheme.roleAdverbial, ink: VocraTheme.roleAdverbialInk)
      }
    }
    .padding(16)
  }

  @ViewBuilder
  private func backField(label: String, text: String, color: Color, ink: Color) -> some View {
    if !text.isEmpty {
      VStack(alignment: .leading, spacing: 3) {
        Text(label)
          .font(.system(size: 10.5, weight: .bold))
          .tracking(0.4)
          .foregroundStyle(ink)
        Text(text)
          .font(.system(size: 13.5))
          .foregroundStyle(VocraTheme.ink900)
          .lineSpacing(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }
}
