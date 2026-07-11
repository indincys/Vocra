import Foundation
import SwiftUI
import VocraCore

// MARK: - Shared atoms for the Liquid Glass lookup popovers

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

private enum SentenceMetrics {
  static let glyph: CGFloat = 17
  static let barHeight: CGFloat = 3
  static let labelSize: CGFloat = 10.5
  /// Space under each word that holds the underline bar (role spans only).
  static let underlinePad: CGFloat = 4
  /// Fixed height reserved for the role label beneath every word, so glyph
  /// baselines stay aligned and line spacing is even across the sentence.
  static let labelHeight: CGFloat = 14
  static let stackSpacing: CGFloat = 2
}

/// The full original sentence, rendered verbatim, with each grammatical
/// constituent underlined in its role color and labeled directly beneath the
/// underline (主语/谓语/连词…). Hovering a labeled span pops a bubble with the
/// sentence-specific note. Connective filler between spans stays plain so the
/// sentence is never broken into fragments.
struct RoleUnderlinedSentence: View {
  let text: String
  let segments: [SentenceSegment]
  @State private var hoveredID: String?

  private var pieces: [SentenceDisplayPiece] {
    sentenceDisplayPieces(text: text, segments: segments)
  }

  var body: some View {
    FlowLayout(spacing: 4, rowSpacing: 7) {
      ForEach(pieces) { piece in
        switch piece.kind {
        case .plain:
          PlainWord(text: piece.text)
        case let .role(segment):
          RoleSpan(text: piece.text, segment: segment, hoveredID: $hoveredID)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A plain (unlabeled) word; reserves the same underline + label height as a
/// labeled span so every line keeps a uniform rhythm and baselines stay aligned.
private struct PlainWord: View {
  let text: String

  var body: some View {
    VStack(spacing: SentenceMetrics.stackSpacing) {
      Text(text)
        .font(.system(size: SentenceMetrics.glyph))
        .foregroundStyle(VocraTheme.ink900)
        .fixedSize()
        .padding(.bottom, SentenceMetrics.underlinePad)
      Color.clear.frame(height: SentenceMetrics.labelHeight)
    }
  }
}

/// A labeled, underlined grammatical span. The colored bar sits flush under the
/// word and the Chinese role label sits under the bar.
private struct RoleSpan: View {
  let text: String
  let segment: SentenceSegment
  @Binding var hoveredID: String?

  private var isHovered: Bool { hoveredID == segment.id }

  var body: some View {
    VStack(spacing: SentenceMetrics.stackSpacing) {
      Text(text)
        .font(.system(size: SentenceMetrics.glyph))
        .foregroundStyle(VocraTheme.ink900)
        .fixedSize()
        .padding(.horizontal, 1)
        .padding(.bottom, SentenceMetrics.underlinePad)
        .background(
          isHovered ? segment.color.vocraColor.opacity(0.16) : .clear,
          in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
        .overlay(alignment: .bottom) {
          RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(segment.color.vocraColor)
            .frame(height: SentenceMetrics.barHeight)
        }
      Text(segment.labelZh)
        .font(.system(size: SentenceMetrics.labelSize, weight: .semibold))
        .foregroundStyle(segment.color.vocraInk)
        .lineLimit(1)
        .fixedSize()
        .frame(height: SentenceMetrics.labelHeight)
    }
    .contentShape(Rectangle())
    .onHover { hovering in
      if hovering { hoveredID = segment.id }
      else if hoveredID == segment.id { hoveredID = nil }
    }
    .popover(
      isPresented: Binding(
        get: { hoveredID == segment.id },
        set: { presented in if !presented, hoveredID == segment.id { hoveredID = nil } }
      ),
      arrowEdge: .bottom
    ) {
      SegmentTooltip(segment: segment)
    }
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
}

/// Reconstructs the full sentence as an ordered list of pieces: plain word
/// tokens for the connective tissue, and role spans for each grammatical
/// constituent located (tolerantly) inside the original text. Works on whole
/// whitespace-delimited tokens so punctuation always stays attached to its
/// word, and guarantees the whole sentence is shown even when the model only
/// marks a few spans.
func sentenceDisplayPieces(text: String, segments: [SentenceSegment]) -> [SentenceDisplayPiece] {
  guard !text.isEmpty else { return [] }
  let tokens = wordTokenRanges(in: text)
  guard !tokens.isEmpty else { return [] }

  // Locate each segment's span, preferring the next forward occurrence so spans
  // stay in reading order; fall back to anywhere if a forward match is missing.
  // Keep only non-overlapping spans (earlier start wins).
  var matches: [(range: Range<String.Index>, segment: SentenceSegment)] = []
  if !segments.isEmpty {
    var cursor = text.startIndex
    for segment in segments {
      guard let range = locateSpan(segment.text, in: text, from: cursor)
        ?? locateSpan(segment.text, in: text, from: text.startIndex)
      else { continue }
      matches.append((range, segment))
      if range.upperBound > cursor { cursor = range.upperBound }
    }
    matches.sort { $0.range.lowerBound < $1.range.lowerBound }
    var deduped: [(range: Range<String.Index>, segment: SentenceSegment)] = []
    for match in matches {
      if let last = deduped.last, match.range.lowerBound < last.range.upperBound { continue }
      deduped.append(match)
    }
    matches = deduped
  }

  // Assign each word token to the span it overlaps most (nil = plain word).
  func assignedSegment(for token: Range<String.Index>) -> Int? {
    var bestIndex: Int?
    var bestOverlap = 0
    for (index, match) in matches.enumerated() {
      let lower = max(token.lowerBound, match.range.lowerBound)
      let upper = min(token.upperBound, match.range.upperBound)
      guard lower < upper else { continue }
      let overlap = text.distance(from: lower, to: upper)
      if overlap > bestOverlap {
        bestOverlap = overlap
        bestIndex = index
      }
    }
    return bestIndex
  }

  // Walk tokens, grouping a run of consecutive tokens that share a span into one
  // labeled role piece; unassigned tokens become individual plain words so the
  // sentence wraps naturally.
  var pieces: [SentenceDisplayPiece] = []
  var runStart: Int?
  var runSegment: Int?
  var plainCounter = 0

  func flushRun(endExclusive: Int) {
    guard let start = runStart, let segIndex = runSegment, endExclusive > start else {
      runStart = nil
      runSegment = nil
      return
    }
    let span = String(text[tokens[start].lowerBound..<tokens[endExclusive - 1].upperBound])
    let segment = matches[segIndex].segment
    pieces.append(SentenceDisplayPiece(id: "seg-\(segment.id)-\(start)", text: span, kind: .role(segment)))
    runStart = nil
    runSegment = nil
  }

  for (index, token) in tokens.enumerated() {
    if let assigned = assignedSegment(for: token) {
      if runSegment == assigned { continue }
      flushRun(endExclusive: index)
      runStart = index
      runSegment = assigned
    } else {
      flushRun(endExclusive: index)
      pieces.append(SentenceDisplayPiece(id: "w-\(plainCounter)", text: String(text[token]), kind: .plain))
      plainCounter += 1
    }
  }
  flushRun(endExclusive: tokens.count)
  return pieces
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

/// Hover bubble: colored role badge + the chunk text + a sentence-specific note
/// (falls back to a generic role description when the model didn't provide one).
private struct SegmentTooltip: View {
  let segment: SentenceSegment

  private var note: String {
    let trimmed = segment.note.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? roleGrammarNote(for: segment) : trimmed
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 7) {
        Text(segment.labelZh)
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(segment.color.vocraInk)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(segment.color.vocraColor.opacity(0.2), in: Capsule())
        Text(segment.text)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(VocraTheme.ink700)
          .lineLimit(2)
      }
      Text(note)
        .font(.system(size: 12.5))
        .foregroundStyle(VocraTheme.ink700)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 13)
    .padding(.vertical, 11)
    .frame(width: 268)
  }
}

/// Generic grammar note for a component, keyed off its Chinese role label.
private func roleGrammarNote(for segment: SentenceSegment) -> String {
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
