import SwiftUI
import VocraCore

struct VocabularyCardLearningView: View {
  let card: StructuredVocabularyCard

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      meaning
      examples
      reviewPrompts
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(card.front.text)
        .font(.title3.weight(.semibold))
        .textSelection(.enabled)

      if let hint = card.front.hint, !hint.isEmpty {
        Text(hint)
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    }
  }

  private var meaning: some View {
    LearningSection(title: "Card Back", systemImage: "rectangle.on.rectangle") {
      VStack(alignment: .leading, spacing: 10) {
        LabeledCardText(label: "Core meaning", text: card.back.coreMeaning)
        LabeledCardText(label: "Memory note", text: card.back.memoryNote)
        LabeledCardText(label: "Usage", text: card.back.usage)
      }
    }
  }

  @ViewBuilder
  private var examples: some View {
    if !card.examples.isEmpty {
      LearningSection(title: "Examples", systemImage: "quote.bubble") {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(card.examples) { example in
            VStack(alignment: .leading, spacing: 4) {
              Text(example.sentence)
                .font(.callout.weight(.medium))
              Text(example.translation)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .textSelection(.enabled)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var reviewPrompts: some View {
    if !card.reviewPrompts.isEmpty {
      LearningSection(title: "Review Prompts", systemImage: "questionmark.circle") {
        BulletList(items: card.reviewPrompts)
      }
    }
  }
}

private struct LabeledCardText: View {
  let label: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(text)
        .font(.body)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
