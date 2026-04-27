import SwiftUI
import VocraCore

struct WordLearningView: View {
  let explanation: WordExplanation

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      meanings
      usageNotes
      collocations
      examples
      commonMistakes
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(explanation.term)
          .font(.title3.weight(.semibold))
          .textSelection(.enabled)

        Text(explanation.partOfSpeech)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(.secondary.opacity(0.12), in: Capsule())
      }

      if let pronunciation = explanation.pronunciation, !pronunciation.isEmpty {
        Label(pronunciation, systemImage: "speaker.wave.2")
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    }
  }

  private var meanings: some View {
    LearningSection(title: "Meaning", systemImage: "sparkle.magnifyingglass") {
      VStack(alignment: .leading, spacing: 10) {
        LabeledText(label: "Core", text: explanation.coreMeaning)
        LabeledText(label: "Context", text: explanation.contextualMeaning)
      }
    }
  }

  @ViewBuilder
  private var usageNotes: some View {
    if !explanation.usageNotes.isEmpty {
      LearningSection(title: "Usage Notes", systemImage: "text.badge.checkmark") {
        BulletList(items: explanation.usageNotes)
      }
    }
  }

  @ViewBuilder
  private var collocations: some View {
    if !explanation.collocations.isEmpty {
      LearningSection(title: "Collocations", systemImage: "link") {
        FlowLayout(spacing: 8, rowSpacing: 8) {
          ForEach(Array(explanation.collocations.enumerated()), id: \.offset) { _, collocation in
            Text(collocation)
              .font(.callout)
              .textSelection(.enabled)
              .padding(.horizontal, 9)
              .padding(.vertical, 6)
              .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
          }
        }
      }
    }
  }

  @ViewBuilder
  private var examples: some View {
    if !explanation.examples.isEmpty {
      LearningSection(title: "Examples", systemImage: "quote.bubble") {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(Array(explanation.examples.enumerated()), id: \.offset) { _, example in
            VStack(alignment: .leading, spacing: 4) {
              Text(example.sentence)
                .font(.callout.weight(.medium))
              Text(example.translation)
                .font(.callout)
                .foregroundStyle(.secondary)
              if let note = example.note, !note.isEmpty {
                Text(note)
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }
            }
            .textSelection(.enabled)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var commonMistakes: some View {
    if !explanation.commonMistakes.isEmpty {
      LearningSection(title: "Common Mistakes", systemImage: "exclamationmark.bubble") {
        BulletList(items: explanation.commonMistakes)
      }
    }
  }
}

private struct LabeledText: View {
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

struct BulletList: View {
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        Label(item, systemImage: "circle.fill")
          .font(.callout)
          .foregroundStyle(.secondary)
          .labelStyle(.titleAndIcon)
          .textSelection(.enabled)
      }
    }
  }
}
