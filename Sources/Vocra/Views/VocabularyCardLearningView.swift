import SwiftUI
import VocraCore

struct VocabularyCardLearningView: View {
  let card: StructuredVocabularyCard

  var body: some View {
    VStack(spacing: 16) {
      hero
      backGrid
      examples
      reviewPrompts
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .top)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(CardPalette.border, lineWidth: 1)
    }
    .textSelection(.enabled)
  }

  private var hero: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(card.front.text)
        .font(.system(size: 36, weight: .heavy, design: .rounded))
        .foregroundStyle(CardPalette.blue)
        .lineLimit(3)
        .minimumScaleFactor(0.7)

      if let hint = card.front.hint, !hint.isEmpty {
        Text(hint)
          .font(.headline.weight(.semibold))
          .foregroundStyle(CardPalette.muted)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(CardPalette.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CardPalette.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(CardPalette.blue.opacity(0.2), lineWidth: 1)
    }
  }

  private var backGrid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
      CardInfoTile(index: 1, titleZh: "核心释义", titleEn: "Core Meaning", text: card.back.coreMeaning, tint: CardPalette.blue)
      CardInfoTile(index: 2, titleZh: "记忆提示", titleEn: "Memory Note", text: card.back.memoryNote, tint: CardPalette.green)
      CardInfoTile(index: 3, titleZh: "使用场景", titleEn: "Usage", text: card.back.usage, tint: CardPalette.orange)
    }
  }

  @ViewBuilder
  private var examples: some View {
    if !card.examples.isEmpty {
      CardSection(titleZh: "例句复习", titleEn: "Examples", icon: "quote.bubble", tint: CardPalette.purple) {
        VStack(spacing: 10) {
          ForEach(Array(card.examples.enumerated()), id: \.offset) { index, example in
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 8) {
                Text("\(index + 1)")
                  .font(.caption.weight(.heavy))
                  .foregroundStyle(.white)
                  .frame(width: 22, height: 22)
                  .background(CardPalette.purple, in: Circle())
                Text(example.sentence)
                  .font(.body.weight(.heavy))
                  .foregroundStyle(CardPalette.ink)
              }
              Text(example.translation)
                .font(.body.weight(.semibold))
                .foregroundStyle(CardPalette.green)
                .padding(.leading, 30)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(CardPalette.border, lineWidth: 1)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var reviewPrompts: some View {
    if !card.reviewPrompts.isEmpty {
      CardSection(titleZh: "复习问题", titleEn: "Review Prompts", icon: "questionmark.circle", tint: CardPalette.pink) {
        VStack(alignment: .leading, spacing: 9) {
          ForEach(Array(card.reviewPrompts.enumerated()), id: \.offset) { index, prompt in
            HStack(alignment: .top, spacing: 10) {
              Text("\(index + 1)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(CardPalette.pink, in: Circle())
              Text(prompt)
                .font(.callout.weight(.semibold))
                .foregroundStyle(CardPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
    }
  }
}

private struct CardInfoTile: View {
  let index: Int
  let titleZh: String
  let titleEn: String
  let text: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 9) {
        Text("\(index)")
          .font(.headline.weight(.heavy))
          .foregroundStyle(.white)
          .frame(width: 28, height: 28)
          .background(tint, in: Circle())
        VStack(alignment: .leading, spacing: 1) {
          Text(titleZh)
            .font(.headline.weight(.heavy))
          Text(titleEn)
            .font(.caption.weight(.semibold))
            .foregroundStyle(CardPalette.muted)
        }
      }

      Text(text)
        .font(.body.weight(.semibold))
        .foregroundStyle(CardPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .stroke(tint.opacity(0.22), lineWidth: 1)
    }
  }
}

private struct CardSection<Content: View>: View {
  let titleZh: String
  let titleEn: String
  let icon: String
  let tint: Color
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 9) {
        Image(systemName: icon)
          .font(.title3.weight(.heavy))
          .foregroundStyle(tint)
          .frame(width: 26)
        VStack(alignment: .leading, spacing: 1) {
          Text(titleZh)
            .font(.headline.weight(.heavy))
          Text(titleEn)
            .font(.caption.weight(.semibold))
            .foregroundStyle(CardPalette.muted)
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

private enum CardPalette {
  static let ink = Color(red: 0.06, green: 0.09, blue: 0.16)
  static let muted = Color(red: 0.42, green: 0.48, blue: 0.56)
  static let border = Color(red: 0.82, green: 0.87, blue: 0.94)
  static let blue = Color(red: 0.05, green: 0.35, blue: 0.82)
  static let green = Color(red: 0.02, green: 0.48, blue: 0.18)
  static let orange = Color(red: 0.95, green: 0.32, blue: 0.02)
  static let purple = Color(red: 0.37, green: 0.16, blue: 0.82)
  static let pink = Color(red: 0.93, green: 0.07, blue: 0.34)
}
