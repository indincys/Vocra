import Foundation
import SwiftUI
import VocraCore

// MARK: - Shared atoms for the learning views

/// Tiny ALL-CAPS-weight micro label (e.g. 例句, 语境理解).
struct PopMicroLabel: View {
  let text: String
  var body: some View {
    Text(text)
      .font(.system(size: 10.5, weight: .bold))
      .tracking(0.4)
      .foregroundStyle(VocraTheme.ink400)
  }
}

/// Section block with an accent glyph header and a leading hairline (matches the
/// prototype's `PSection`).
struct PopSection<Content: View>: View {
  let icon: String
  let title: String
  var hint: String?
  var first = false
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 7) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(VocraTheme.accent)
        Text(title)
          .font(.system(size: 12.5, weight: .bold))
          .foregroundStyle(VocraTheme.ink700)
          .tracking(0.2)
        if let hint {
          Text("· \(hint)").font(.system(size: 11)).foregroundStyle(VocraTheme.ink400)
        }
      }
      content
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .top) {
      if !first { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
    }
  }
}

/// Light inset box used for context / backbone / example callouts.
struct PopInset<Content: View>: View {
  var tint: Color?
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background((tint ?? VocraTheme.fill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

/// Pill button that adds the current word/term to the vocabulary book.
struct SaveVocabularyButton: View {
  let saved: Bool
  let action: () -> Void

  var body: some View {
    Button {
      if !saved { action() }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: saved ? "checkmark" : "plus").font(.system(size: 12, weight: .bold))
        Text(saved ? "已加入生词本" : "加入生词本").font(.system(size: 12.5, weight: .semibold))
      }
      .foregroundStyle(saved ? VocraTheme.ink500 : Color.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background {
        if saved {
          Capsule().fill(VocraTheme.fill)
        } else {
          Capsule().fill(LinearGradient(colors: [VocraTheme.accent, VocraTheme.accentStrong], startPoint: .top, endPoint: .bottom))
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(saved)
  }
}

/// Compact +/✓ button for adding a single key term to the vocabulary book.
struct SaveTermButton: View {
  let saved: Bool
  let action: () -> Void

  var body: some View {
    Button {
      if !saved { action() }
    } label: {
      Image(systemName: saved ? "checkmark.circle.fill" : "plus.circle")
        .font(.system(size: 16))
        .foregroundStyle(saved ? VocraTheme.roleObjectInk : VocraTheme.accent)
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(saved ? "已加入生词本" : "加入生词本")
  }
}

/// Builds a minimal vocabulary-card document for a term saved from a lookup.
func makeVocabularyCardDocument(term: String, meaning: String, note: String) -> LearningExplanationDocument {
  let type: VocabularyType = term.trimmingCharacters(in: .whitespaces).contains(" ") ? .phrase : .word
  return LearningExplanationDocument(
    schemaVersion: LearningExplanationDocument.currentSchemaVersion,
    mode: type == .word ? .word : .phrase,
    sourceText: term,
    language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
    sentenceAnalysis: nil,
    wordExplanation: nil,
    vocabularyCard: StructuredVocabularyCard(
      front: VocabularyCardFront(text: term, hint: nil),
      back: VocabularyCardBack(coreMeaning: meaning, memoryNote: "", usage: note),
      examples: [],
      reviewPrompts: []
    ),
    warnings: []
  )
}

func vocabularyType(for term: String) -> VocabularyType {
  term.trimmingCharacters(in: .whitespaces).contains(" ") ? .phrase : .word
}

/// Small numbered accent circle for ordered steps.
struct PopNumber: View {
  let number: Int
  var color: Color = VocraTheme.accent
  var body: some View {
    Text("\(number)")
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: 21, height: 21)
      .background(color, in: Circle())
  }
}

// MARK: - Sentence tiling

/// One renderable unit of the underlined sentence.
struct SentenceDisplayPiece: Identifiable, Equatable {
  enum Kind: Equatable {
    case plain
    case role(SentenceSegment)
  }

  let id: String
  let text: String
  let kind: Kind
  /// The key-vocabulary entry covering this piece, when one overlaps it. A piece can carry
  /// both a grammatical role and a key term (e.g. the object *is* the word worth learning).
  var keyTerm: KeyVocabularyItem?

  var segment: SentenceSegment? {
    if case let .role(segment) = kind { return segment }
    return nil
  }

  /// Whether the piece has anything to explain, i.e. whether it should be tappable.
  var isExplainable: Bool { segment != nil || keyTerm != nil }
}

/// Reconstructs the full sentence as an ordered list of pieces: plain word tokens for the
/// connective tissue, and marked spans for each grammatical constituent and each key
/// vocabulary term located (tolerantly) inside the original text. Works on whole
/// whitespace-delimited tokens so punctuation always stays attached to its word, and
/// guarantees the whole sentence is shown even when the model only marks a few spans.
///
/// A run of tokens is merged into one piece only while both its role span and its key term
/// stay the same, so a key word inside a larger clause still gets its own tappable piece.
func sentenceDisplayPieces(
  text: String,
  segments: [SentenceSegment],
  keyVocabulary: [KeyVocabularyItem] = []
) -> [SentenceDisplayPiece] {
  guard !text.isEmpty else { return [] }
  let tokens = wordTokenRanges(in: text)
  guard !tokens.isEmpty else { return [] }

  let segmentMatches = locateAll(segments.map(\.text), in: text)
  let termMatches = locateAll(keyVocabulary.map(\.term), in: text)

  /// Index of the match that overlaps `token` the most (nil when none does).
  func assignment(for token: Range<String.Index>, in matches: [(range: Range<String.Index>, index: Int)]) -> Int? {
    var best: Int?
    var bestOverlap = 0
    for match in matches {
      let lower = max(token.lowerBound, match.range.lowerBound)
      let upper = min(token.upperBound, match.range.upperBound)
      guard lower < upper else { continue }
      let overlap = text.distance(from: lower, to: upper)
      if overlap > bestOverlap {
        bestOverlap = overlap
        best = match.index
      }
    }
    return best
  }

  var pieces: [SentenceDisplayPiece] = []
  var runStart: Int?
  var runKey: (Int?, Int?)?
  var plainCounter = 0

  func flushRun(endExclusive: Int) {
    defer { runStart = nil; runKey = nil }
    guard let start = runStart, let key = runKey, endExclusive > start else { return }
    let span = String(text[tokens[start].lowerBound..<tokens[endExclusive - 1].upperBound])
    let segment = key.0.map { segments[$0] }
    let term = key.1.map { keyVocabulary[$0] }
    let id = "sp-\(segment?.id ?? "term")-\(term?.term ?? "")-\(start)"
    pieces.append(SentenceDisplayPiece(
      id: id,
      text: span,
      kind: segment.map { .role($0) } ?? .plain,
      keyTerm: term
    ))
  }

  for (index, token) in tokens.enumerated() {
    let key = (assignment(for: token, in: segmentMatches), assignment(for: token, in: termMatches))
    guard key.0 != nil || key.1 != nil else {
      flushRun(endExclusive: index)
      pieces.append(SentenceDisplayPiece(id: "w-\(plainCounter)", text: String(text[token]), kind: .plain))
      plainCounter += 1
      continue
    }
    if let runKey, runKey == key { continue }
    flushRun(endExclusive: index)
    runStart = index
    runKey = key
  }
  flushRun(endExclusive: tokens.count)
  return pieces
}

/// Locates each needle in `text`, preferring the next forward occurrence so spans stay in
/// reading order, and keeps only non-overlapping matches (earlier start wins). The returned
/// index is the needle's position in the input array.
private func locateAll(_ needles: [String], in text: String) -> [(range: Range<String.Index>, index: Int)] {
  guard !needles.isEmpty else { return [] }
  var matches: [(range: Range<String.Index>, index: Int)] = []
  var cursor = text.startIndex
  for (index, needle) in needles.enumerated() {
    guard let range = locateSpan(needle, in: text, from: cursor)
      ?? locateSpan(needle, in: text, from: text.startIndex)
    else { continue }
    matches.append((range, index))
    if range.upperBound > cursor { cursor = range.upperBound }
  }
  matches.sort { $0.range.lowerBound < $1.range.lowerBound }

  var deduped: [(range: Range<String.Index>, index: Int)] = []
  for match in matches {
    if let last = deduped.last, match.range.lowerBound < last.range.upperBound { continue }
    deduped.append(match)
  }
  return deduped
}

/// The character ranges of every whitespace-delimited token in `text`.
private func wordTokenRanges(in text: String) -> [Range<String.Index>] {
  var result: [Range<String.Index>] = []
  var index = text.startIndex
  while index < text.endIndex {
    while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
    guard index < text.endIndex else { break }
    let start = index
    while index < text.endIndex, !text[index].isWhitespace { index = text.index(after: index) }
    result.append(start..<index)
  }
  return result
}

/// Finds `needle` inside `haystack` at or after `start`, tolerating case and
/// whitespace differences between the model's span and the original sentence.
private func locateSpan(_ needle: String, in haystack: String, from start: String.Index) -> Range<String.Index>? {
  let trimmed = needle.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty, start <= haystack.endIndex else { return nil }
  let window = start..<haystack.endIndex
  if let range = haystack.range(of: trimmed, range: window) { return range }
  if let range = haystack.range(of: trimmed, options: .caseInsensitive, range: window) { return range }
  let pattern = NSRegularExpression.escapedPattern(for: trimmed)
    .replacingOccurrences(of: "\\s+", with: "\\\\s+", options: .regularExpression)
  return haystack.range(of: pattern, options: [.regularExpression, .caseInsensitive], range: window)
}

/// Generic grammar note for a component, keyed off its Chinese role label. Used when the
/// model didn't supply a sentence-specific note.
func roleGrammarNote(for segment: SentenceSegment) -> String {
  let label = segment.labelZh
  if label.contains("主语") { return "句子的动作发出者。" }
  if label.contains("谓语") { return "描述主语的动作或状态，是句子的核心。" }
  if label.contains("宾语") { return "动作所涉及或承受的对象。" }
  if label.contains("表语") { return "说明主语「是什么 / 怎么样」。" }
  if label.contains("定语") { return "修饰名词或代词的成分。" }
  if label.contains("补语") { return "补充说明动作的结果、程度或对象。" }
  if label.contains("状语") { return "修饰动词，说明时间、地点、方式、原因等。" }
  if label.contains("转折") { return "表示语义转折，理解重心通常落在其后。" }
  if label.contains("连接") || label.contains("连词") { return "连接成分或分句的纽带。" }
  if label.contains("从句") { return "充当句子成分的小句。" }
  if label.contains("主句") || label.contains("主干") { return "句子的核心分句。" }
  if label.contains("并列") { return "与其它成分地位对等、并列出现。" }
  return "句子的组成成分。"
}
