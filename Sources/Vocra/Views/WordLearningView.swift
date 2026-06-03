import SwiftUI
import VocraCore

struct WordLearningView: View {
  let explanation: WordExplanation

  var body: some View {
    VStack(spacing: 0) {
      header
      if !explanation.examples.isEmpty {
        PopSection(icon: "quote.bubble", title: "例句") {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(explanation.examples.enumerated()), id: \.offset) { _, example in
              ExampleRow(example: example)
            }
          }
        }
      }
      if !explanation.usageNotes.isEmpty {
        PopSection(icon: "checkmark.seal", title: "用法提示") {
          BulletList(items: explanation.usageNotes, tint: VocraTheme.accent)
        }
      }
      if !explanation.collocations.isEmpty {
        PopSection(icon: "link", title: "常见搭配") {
          FlowLayout(spacing: 7, rowSpacing: 7) {
            ForEach(Array(explanation.collocations.enumerated()), id: \.offset) { _, collocation in
              Text(collocation)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(VocraTheme.roleClauseInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(VocraTheme.roleClause.opacity(0.14), in: Capsule())
            }
          }
        }
      }
      if !explanation.commonMistakes.isEmpty {
        PopSection(icon: "exclamationmark.triangle", title: "易错点") {
          BulletList(items: explanation.commonMistakes, tint: VocraTheme.roleTransition)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .textSelection(.enabled)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 9) {
        Text(explanation.term)
          .font(.system(size: 25, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
        VocraChip(text: explanation.partOfSpeech, tint: VocraTheme.accentInk, monospaced: true)
        Spacer(minLength: 0)
      }
      if let pronunciation = explanation.pronunciation, !pronunciation.isEmpty {
        HStack(spacing: 8) {
          Text(pronunciation)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(VocraTheme.ink500)
          SpeakerButton(text: explanation.term, size: 14)
        }
        .padding(.top, 4)
      }

      Text(explanation.coreMeaning)
        .font(.system(size: 15))
        .foregroundStyle(VocraTheme.ink900)
        .lineSpacing(3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)

      if !explanation.contextualMeaning.isEmpty {
        PopInset {
          VStack(alignment: .leading, spacing: 3) {
            PopMicroLabel(text: "语境理解")
            Text(explanation.contextualMeaning)
              .font(.system(size: 13))
              .foregroundStyle(VocraTheme.ink700)
              .lineSpacing(2)
          }
        }
        .padding(.top, 10)
      }
    }
    .padding(16)
  }
}

private struct ExampleRow: View {
  let example: LearningExample

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      SpeakerButton(text: example.sentence, size: 13)
      VStack(alignment: .leading, spacing: 2) {
        Text(example.sentence)
          .font(.system(size: 14))
          .foregroundStyle(VocraTheme.ink900)
          .lineSpacing(2)
        Text(example.translation)
          .font(.system(size: 13))
          .foregroundStyle(VocraTheme.ink500)
        if let note = example.note, !note.isEmpty {
          Text(note)
            .font(.system(size: 12))
            .foregroundStyle(VocraTheme.ink400)
            .padding(.top, 1)
        }
      }
      Spacer(minLength: 0)
    }
  }
}

private struct BulletList: View {
  let items: [String]
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        HStack(alignment: .top, spacing: 9) {
          Circle().fill(tint).frame(width: 5, height: 5).padding(.top, 7)
          Text(item)
            .font(.system(size: 13))
            .foregroundStyle(VocraTheme.ink700)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}
