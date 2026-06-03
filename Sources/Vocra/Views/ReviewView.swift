import SwiftUI
import VocraCore

struct ReviewView: View {
  let cards: [VocabularyCard]
  let onRate: (UUID, ReviewRating) -> Void

  @State private var index = 0
  @State private var flipped = false
  @State private var results: [ReviewRating] = []
  @State private var finished = false

  private static let ratings: [(rating: ReviewRating, label: String, interval: String, hue: Double)] = [
    (.forgot, "忘记", "<1m", 25),
    (.vague, "模糊", "10m", 65),
    (.familiar, "认识", "1d", 150),
    (.mastered, "熟练", "4d", 255),
  ]

  var body: some View {
    if cards.isEmpty {
      emptyState
    } else if finished || index >= cards.count {
      completionState
    } else {
      reviewing(card: cards[index])
    }
  }

  private func reviewing(card: VocabularyCard) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        ZStack(alignment: .leading) {
          Capsule().fill(VocraTheme.fillStrong)
          GeometryReader { geo in
            Capsule()
              .fill(VocraTheme.accent)
              .frame(width: geo.size.width * (CGFloat(index) / CGFloat(max(cards.count, 1))))
          }
        }
        .frame(height: 6)
        Text("\(index + 1) / \(cards.count)")
          .font(.system(size: 13, weight: .medium).monospacedDigit())
          .foregroundStyle(VocraTheme.ink500)
      }
      .padding(.bottom, 20)

      Spacer()
      flashcard(card: card)
        .frame(width: 460, height: 280)
      Spacer()

      ratingRow(card: card)
        .padding(.top, 20)
      Text("间隔重复算法会根据你的反馈安排下次复习时间")
        .font(.system(size: 11.5))
        .foregroundStyle(VocraTheme.ink400)
        .padding(.top, 10)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func flashcard(card: VocabularyCard) -> some View {
    ZStack {
      cardFront(card: card)
        .opacity(flipped ? 0 : 1)
        .scaleEffect(flipped ? 0.96 : 1)
      cardBack(card: card)
        .opacity(flipped ? 1 : 0)
        .scaleEffect(flipped ? 1 : 0.96)
    }
    .animation(.easeInOut(duration: 0.28), value: flipped)
    .contentShape(Rectangle())
    .onTapGesture { flipped.toggle() }
  }

  private func cardFront(card: VocabularyCard) -> some View {
    VStack(spacing: 8) {
      Text(card.text)
        .font(.system(size: 40, weight: .bold))
        .foregroundStyle(VocraTheme.ink900)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
      if let pronunciation = card.displayPronunciation {
        Text(pronunciation)
          .font(.system(size: 16, design: .monospaced))
          .foregroundStyle(VocraTheme.ink500)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .topLeading) {
      VocraChip(text: card.displayPartOfSpeech, tint: VocraTheme.accentInk, monospaced: true)
        .padding(16)
    }
    .overlay(alignment: .topTrailing) {
      SpeakerButton(text: card.text, size: 18).padding(10)
    }
    .overlay(alignment: .bottom) {
      Text("点击翻面查看释义")
        .font(.system(size: 12))
        .foregroundStyle(VocraTheme.ink400)
        .padding(.bottom, 16)
    }
    .vocraGlassPanel(cornerRadius: 22)
  }

  private func cardBack(card: VocabularyCard) -> some View {
    let example = firstExample(card)
    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text(card.text)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
        VocraChip(text: card.displayPartOfSpeech, tint: VocraTheme.accentInk, monospaced: true)
      }
      Text(card.displayGloss)
        .font(.system(size: 17))
        .foregroundStyle(VocraTheme.ink900)
        .fixedSize(horizontal: false, vertical: true)
      if let example {
        Text("“\(example)”")
          .font(.system(size: 13.5))
          .italic()
          .foregroundStyle(VocraTheme.ink700)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 12)
          .padding(.vertical, 9)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      Spacer(minLength: 0)
      Text("来自 \(card.displaySource)")
        .font(.system(size: 11.5))
        .foregroundStyle(VocraTheme.ink400)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(26)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .vocraGlassPanel(cornerRadius: 22)
  }

  private func ratingRow(card: VocabularyCard) -> some View {
    HStack(spacing: 10) {
      ForEach(Self.ratings, id: \.label) { item in
        Button {
          rate(item.rating, cardID: card.id)
        } label: {
          VStack(spacing: 2) {
            Text(item.label).font(.system(size: 14, weight: .semibold))
            Text(item.interval).font(.system(size: 10.5, design: .monospaced)).opacity(0.7)
          }
          .foregroundStyle(VocraTheme.hued(item.hue, lightness: 0.46))
          .frame(maxWidth: 110)
          .padding(.vertical, 10)
          .background(VocraTheme.hued(item.hue).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: 470)
    .opacity(flipped ? 1 : 0.4)
    .allowsHitTesting(flipped)
    .animation(.easeOut(duration: 0.25), value: flipped)
  }

  private var completionState: some View {
    let known = results.filter { $0 == .familiar || $0 == .mastered }.count
    return VStack(spacing: 18) {
      ZStack {
        Circle().fill(VocraTheme.accentSoft).frame(width: 76, height: 76)
        Image(systemName: "checkmark")
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(VocraTheme.accent)
      }
      Text("今日复习完成")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(VocraTheme.ink900)
      Text("复习 \(results.count) 张 · 熟练 \(known) 🔥")
        .font(.system(size: 15))
        .foregroundStyle(VocraTheme.ink500)
      Button { restart() } label: {
        Label("再来一组", systemImage: "rectangle.stack")
          .font(.system(size: 14, weight: .semibold))
      }
      .buttonStyle(VocraAccentButtonStyle(horizontalPadding: 18, verticalPadding: 9))
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyState: some View {
    VStack(spacing: 14) {
      ZStack {
        Circle().fill(VocraTheme.accentSoft).frame(width: 76, height: 76)
        Image(systemName: "checkmark")
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(VocraTheme.accent)
      }
      Text("没有待复习的卡片")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(VocraTheme.ink900)
      Text("当有单词到达复习时间时，会出现在这里。")
        .font(.system(size: 13))
        .foregroundStyle(VocraTheme.ink500)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func rate(_ rating: ReviewRating, cardID: UUID) {
    onRate(cardID, rating)
    results.append(rating)
    flipped = false
    if index + 1 >= cards.count {
      finished = true
    } else {
      index += 1
    }
  }

  private func restart() {
    index = 0
    flipped = false
    results = []
    finished = false
  }

  private func firstExample(_ card: VocabularyCard) -> String? {
    guard let document = card.decodedDocument else { return nil }
    if let example = document.wordExplanation?.examples.first { return example.sentence }
    if let example = document.vocabularyCard?.examples.first { return example.sentence }
    return nil
  }
}
