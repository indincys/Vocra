import SwiftUI
import VocraCore

struct VocabularyListView: View {
  let cards: [VocabularyCard]
  var onOpen: (VocabularyCard) -> Void = { _ in }

  @State private var query = ""
  @State private var selectedTag = "全部"

  private var tags: [(name: String, count: Int)] {
    var counts: [String: Int] = [:]
    for card in cards { counts[card.displaySource, default: 0] += 1 }
    let sorted = counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
    return sorted.prefix(5).map { ($0.key, $0.value) }
  }

  private var filtered: [VocabularyCard] {
    cards.filter { card in
      let matchesTag = selectedTag == "全部" || card.displaySource == selectedTag
      let trimmed = query.trimmingCharacters(in: .whitespaces)
      let matchesQuery = trimmed.isEmpty
        || card.text.localizedCaseInsensitiveContains(trimmed)
        || card.displayGloss.localizedCaseInsensitiveContains(trimmed)
      return matchesTag && matchesQuery
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      if cards.isEmpty {
        emptyState
      } else {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(filtered) { card in
              VocabularyRow(card: card) { onOpen(card) }
            }
          }
          .padding(.horizontal, 22)
          .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
      }
    }
  }

  private var header: some View {
    VStack(spacing: 16) {
      HStack(spacing: 12) {
        Text("生词本")
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
        Text("\(cards.count) 个词条")
          .font(.system(size: 14))
          .foregroundStyle(VocraTheme.ink400)
        Spacer()
        HStack(spacing: 7) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 13))
            .foregroundStyle(VocraTheme.ink400)
          TextField("搜索单词或释义", text: $query)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(VocraTheme.ink900)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .frame(width: 220)
        .background(VocraTheme.fill, in: Capsule(style: .continuous))
      }

      if !tags.isEmpty {
        HStack(spacing: 8) {
          TagChip(name: "全部", count: nil, hue: nil, selected: selectedTag == "全部") { selectedTag = "全部" }
          ForEach(tags, id: \.name) { tag in
            TagChip(name: tag.name, count: tag.count, hue: stableHue(for: tag.name), selected: selectedTag == tag.name) {
              selectedTag = tag.name
            }
          }
          Spacer(minLength: 0)
        }
      }
    }
    .padding(.horizontal, 34)
    .padding(.top, 26)
    .padding(.bottom, 14)
  }

  private var emptyState: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: "book.closed")
        .font(.system(size: 40))
        .foregroundStyle(VocraTheme.accent.opacity(0.7))
      Text("生词本还是空的")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(VocraTheme.ink900)
      Text("查询过的单词和词组会自动收藏到这里，方便日后复习。")
        .font(.system(size: 13))
        .foregroundStyle(VocraTheme.ink500)
        .multilineTextAlignment(.center)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}

private struct TagChip: View {
  let name: String
  let count: Int?
  let hue: Double?
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let hue {
          Circle()
            .fill(selected ? Color.white : VocraTheme.hued(hue))
            .frame(width: 7, height: 7)
        }
        Text(name)
          .font(.system(size: 13, weight: .medium))
        if let count {
          Text("\(count)")
            .font(.system(size: 11.5))
            .opacity(0.7)
        }
      }
      .foregroundStyle(selected ? Color.white : VocraTheme.ink700)
      .padding(.horizontal, 13)
      .padding(.vertical, 6)
      .background {
        if selected {
          Capsule().fill(VocraTheme.accent)
        } else {
          Capsule().fill(VocraTheme.fill)
        }
      }
    }
    .buttonStyle(.plain)
  }
}

private struct VocabularyRow: View {
  let card: VocabularyCard
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 14) {
      SpeakerButton(text: card.text, size: 16)
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 8) {
          Text(card.text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(VocraTheme.ink900)
            .lineLimit(1)
          if card.isDue {
            Circle().fill(VocraTheme.accent).frame(width: 7, height: 7)
          }
        }
        if let pronunciation = card.displayPronunciation {
          Text(pronunciation)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(VocraTheme.ink400)
        }
      }
      .frame(width: 150, alignment: .leading)

      Text(card.displayGloss)
        .font(.system(size: 14.5))
        .foregroundStyle(VocraTheme.ink700)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)

      MasteryBar(value: card.displayMastery)
      VocraChip(text: card.displaySource)
      Text(vocraRelativeTime(from: card.createdAt))
        .font(.system(size: 12))
        .foregroundStyle(VocraTheme.ink400)
        .frame(width: 70, alignment: .trailing)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .background(hovering ? VocraTheme.fill : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .contentShape(Rectangle())
    .onTapGesture { action() }
    .onHover { hovering = $0 }
  }
}

/// Deterministic, pleasant hue for a tag label (stable within and across runs).
func stableHue(for text: String) -> Double {
  var hash: UInt64 = 5381
  for scalar in text.unicodeScalars {
    hash = (hash &* 33) &+ UInt64(scalar.value)
  }
  return Double(hash % 360)
}
