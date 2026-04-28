import SwiftUI
import VocraCore

struct WordLearningView: View {
  let explanation: WordExplanation

  var body: some View {
    VStack(spacing: 16) {
      WordHero(explanation: explanation)
      meaningGrid
      usageAndCollocations
      examples
      commonMistakes
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .top)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(StudyPalette.border, lineWidth: 1)
    }
    .textSelection(.enabled)
  }

  private var meaningGrid: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 14) {
        StudyCard(
          titleZh: "核心释义",
          titleEn: "Core Meaning",
          systemImage: "sparkle.magnifyingglass",
          tint: StudyPalette.blue
        ) {
          Text(explanation.coreMeaning)
            .font(.title3.weight(.heavy))
            .foregroundStyle(StudyPalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        StudyCard(
          titleZh: "语境含义",
          titleEn: "Context Meaning",
          systemImage: "scope",
          tint: StudyPalette.green
        ) {
          Text(explanation.contextualMeaning)
            .font(.body.weight(.semibold))
            .foregroundStyle(StudyPalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      VStack(spacing: 14) {
        StudyCard(
          titleZh: "核心释义",
          titleEn: "Core Meaning",
          systemImage: "sparkle.magnifyingglass",
          tint: StudyPalette.blue
        ) {
          Text(explanation.coreMeaning)
            .font(.title3.weight(.heavy))
            .foregroundStyle(StudyPalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        StudyCard(
          titleZh: "语境含义",
          titleEn: "Context Meaning",
          systemImage: "scope",
          tint: StudyPalette.green
        ) {
          Text(explanation.contextualMeaning)
            .font(.body.weight(.semibold))
            .foregroundStyle(StudyPalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private var usageAndCollocations: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 14) {
        usageNotes
        collocations
      }

      VStack(spacing: 14) {
        usageNotes
        collocations
      }
    }
  }

  @ViewBuilder
  private var usageNotes: some View {
    if !explanation.usageNotes.isEmpty {
      StudyCard(
        titleZh: "用法提示",
        titleEn: "Usage Notes",
        systemImage: "checklist.checked",
        tint: StudyPalette.orange
      ) {
        NumberedTextList(items: explanation.usageNotes, tint: StudyPalette.orange)
      }
    }
  }

  @ViewBuilder
  private var collocations: some View {
    if !explanation.collocations.isEmpty {
      StudyCard(
        titleZh: "常见搭配",
        titleEn: "Collocations",
        systemImage: "link",
        tint: StudyPalette.purple
      ) {
        FlowLayout(spacing: 9, rowSpacing: 9) {
          ForEach(Array(explanation.collocations.enumerated()), id: \.offset) { index, collocation in
            CollocationChip(index: index + 1, text: collocation)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var examples: some View {
    if !explanation.examples.isEmpty {
      StudyCard(
        titleZh: "例句讲解",
        titleEn: "Examples",
        systemImage: "quote.bubble",
        tint: StudyPalette.blue
      ) {
        VStack(spacing: 10) {
          ForEach(Array(explanation.examples.enumerated()), id: \.offset) { index, example in
            ExampleStudyCard(index: index + 1, example: example)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var commonMistakes: some View {
    if !explanation.commonMistakes.isEmpty {
      StudyCard(
        titleZh: "易错点",
        titleEn: "Common Mistakes",
        systemImage: "exclamationmark.bubble",
        tint: StudyPalette.pink
      ) {
        NumberedTextList(items: explanation.commonMistakes, tint: StudyPalette.pink)
      }
    }
  }
}

private struct WordHero: View {
  let explanation: WordExplanation

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(explanation.term)
          .font(.system(size: 38, weight: .heavy, design: .rounded))
          .foregroundStyle(StudyPalette.blue)
          .lineLimit(3)
          .minimumScaleFactor(0.7)

        Text(explanation.partOfSpeech)
          .font(.callout.weight(.bold))
          .foregroundStyle(StudyPalette.green)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(StudyPalette.green.opacity(0.1), in: Capsule())
          .overlay {
            Capsule().stroke(StudyPalette.green.opacity(0.25), lineWidth: 1)
          }
      }

      if let pronunciation = explanation.pronunciation, !pronunciation.isEmpty {
        HStack(spacing: 8) {
          Image(systemName: "speaker.wave.2.fill")
            .foregroundStyle(StudyPalette.orange)
          Text(pronunciation)
            .font(.title3.weight(.semibold))
            .foregroundStyle(StudyPalette.ink)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(StudyPalette.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(StudyPalette.blue.opacity(0.2), lineWidth: 1)
    }
  }
}

private struct StudyCard<Content: View>: View {
  let titleZh: String
  let titleEn: String
  let systemImage: String
  let tint: Color
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 9) {
        Image(systemName: systemImage)
          .font(.title3.weight(.heavy))
          .foregroundStyle(tint)
          .frame(width: 26)

        VStack(alignment: .leading, spacing: 1) {
          Text(titleZh)
            .font(.headline.weight(.heavy))
          Text(titleEn)
            .font(.caption.weight(.semibold))
            .foregroundStyle(StudyPalette.muted)
        }
      }

      content
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .stroke(tint.opacity(0.22), lineWidth: 1)
    }
  }
}

private struct NumberedTextList: View {
  let items: [String]
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        HStack(alignment: .top, spacing: 10) {
          Text("\(index + 1)")
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(tint, in: Circle())

          Text(item)
            .font(.callout.weight(.semibold))
            .foregroundStyle(StudyPalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}

private struct CollocationChip: View {
  let index: Int
  let text: String

  var body: some View {
    HStack(spacing: 7) {
      Text("\(index)")
        .font(.caption.weight(.heavy))
        .foregroundStyle(.white)
        .frame(width: 21, height: 21)
        .background(StudyPalette.purple, in: Circle())

      Text(text)
        .font(.callout.weight(.bold))
        .foregroundStyle(StudyPalette.purple)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 8)
    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(StudyPalette.purple.opacity(0.2), lineWidth: 1)
    }
  }
}

private struct ExampleStudyCard: View {
  let index: Int
  let example: LearningExample

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(index)")
        .font(.headline.weight(.heavy))
        .foregroundStyle(.white)
        .frame(width: 30, height: 30)
        .background(StudyPalette.blue, in: Circle())

      VStack(alignment: .leading, spacing: 6) {
        Text(example.sentence)
          .font(.body.weight(.heavy))
          .foregroundStyle(StudyPalette.ink)
        Text(example.translation)
          .font(.body.weight(.semibold))
          .foregroundStyle(StudyPalette.green)
        if let note = example.note, !note.isEmpty {
          Text(note)
            .font(.caption.weight(.semibold))
            .foregroundStyle(StudyPalette.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(StudyPalette.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(StudyPalette.border, lineWidth: 1)
    }
  }
}

private enum StudyPalette {
  static let ink = Color(red: 0.06, green: 0.09, blue: 0.16)
  static let muted = Color(red: 0.42, green: 0.48, blue: 0.56)
  static let border = Color(red: 0.82, green: 0.87, blue: 0.94)
  static let blue = Color(red: 0.05, green: 0.35, blue: 0.82)
  static let green = Color(red: 0.02, green: 0.48, blue: 0.18)
  static let orange = Color(red: 0.95, green: 0.32, blue: 0.02)
  static let purple = Color(red: 0.37, green: 0.16, blue: 0.82)
  static let pink = Color(red: 0.93, green: 0.07, blue: 0.34)
}
