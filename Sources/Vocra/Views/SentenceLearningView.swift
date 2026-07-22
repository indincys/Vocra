import SwiftUI
import VocraCore

/// A sentence explained in place.
///
/// The whole view is the sentence itself: every grammatical span carries a colored underline
/// with its Chinese role beneath, and every key word carries a soft highlight. Tapping any of
/// them opens its explanation **directly under the line that span sits on** — no popover, no
/// separate pane, so the reader's eye never leaves the word. The translation sits underneath
/// as the one piece of always-visible context.
struct SentenceLearningView: View {
  let analysis: SentenceAnalysis
  var onSaveVocabulary: VocabularySaveAction? = nil

  @State private var selectedPieceID: String?
  @State private var savedTerms: Set<String> = []

  private var pieces: [SentenceDisplayPiece] {
    sentenceDisplayPieces(
      text: analysis.sentence.text,
      segments: analysis.sentence.segments,
      keyVocabulary: analysis.keyVocabulary
    )
  }

  /// Key terms the model returned that aren't actually findable in the sentence. They can't
  /// be underlined in place, so they get a small list rather than being silently dropped.
  private var unplacedTerms: [KeyVocabularyItem] {
    let placed = Set(pieces.compactMap(\.keyTerm?.term))
    return analysis.keyVocabulary.filter { !placed.contains($0.term) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      sentence
      translation
      leftoverTerms
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Sentence

  @ViewBuilder
  private var sentence: some View {
    let pieces = pieces
    if pieces.isEmpty {
      Text(analysis.sentence.text)
        .font(.system(size: 17))
        .foregroundStyle(VocraTheme.ink900)
        .lineSpacing(5)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    } else {
      InlineExpansionFlow(expandedIndex: pieces.firstIndex { $0.id == selectedPieceID }) {
        ForEach(pieces) { piece in
          SentencePiece(
            piece: piece,
            isSelected: piece.id == selectedPieceID,
            onTap: { toggle(piece) }
          )
        }
        // Always the last subview, and only read when a piece is selected — the layout
        // places it on its own full-width row beneath the selected piece's row.
        if let selected = pieces.first(where: { $0.id == selectedPieceID }) {
          SentenceInlineCard(
            piece: selected,
            saved: selected.keyTerm.map { savedTerms.contains($0.term) } ?? false,
            onSave: onSaveVocabulary.map { save in
              { (item: KeyVocabularyItem) in
                save(item.term, vocabularyType(for: item.term), makeVocabularyCardDocument(
                  term: item.term,
                  meaning: item.meaning,
                  note: item.note
                ))
                savedTerms.insert(item.term)
              }
            }
          )
        }
      }
      .padding(18)
      .animation(.snappy(duration: 0.22), value: selectedPieceID)
    }
  }

  private func toggle(_ piece: SentenceDisplayPiece) {
    guard piece.isExplainable else { return }
    selectedPieceID = selectedPieceID == piece.id ? nil : piece.id
  }

  // MARK: Translation

  @ViewBuilder
  private var translation: some View {
    let text = analysis.translation.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
      HStack(alignment: .top, spacing: 9) {
        Image(systemName: "text.bubble")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(VocraTheme.accent)
          .padding(.top, 2)
        Text(text)
          .font(.system(size: 14))
          .foregroundStyle(VocraTheme.ink700)
          .lineSpacing(4)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .overlay(alignment: .top) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
    }
  }

  @ViewBuilder
  private var leftoverTerms: some View {
    let terms = unplacedTerms
    if !terms.isEmpty {
      VStack(alignment: .leading, spacing: 7) {
        ForEach(terms) { item in
          HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(item.term)
              .font(.system(size: 13.5, weight: .semibold))
              .foregroundStyle(VocraTheme.ink900)
            Text(item.meaning)
              .font(.system(size: 12.5))
              .foregroundStyle(VocraTheme.accentInk)
            Spacer(minLength: 0)
            SpeakerButton(text: item.term, size: 12)
            if let onSaveVocabulary {
              SaveTermButton(saved: savedTerms.contains(item.term)) {
                onSaveVocabulary(
                  item.term,
                  vocabularyType(for: item.term),
                  makeVocabularyCardDocument(term: item.term, meaning: item.meaning, note: item.note)
                )
                savedTerms.insert(item.term)
              }
            }
          }
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 13)
      .overlay(alignment: .top) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
    }
  }
}

// MARK: - One span of the sentence

private enum SentenceMetrics {
  static let glyph: CGFloat = 17
  static let barHeight: CGFloat = 3
  static let labelSize: CGFloat = 10.5
  /// Space under each word that holds the underline bar (role spans only).
  static let underlinePad: CGFloat = 4
  /// Fixed height reserved for the role label beneath every word, so glyph baselines stay
  /// aligned and line spacing is even across the sentence.
  static let labelHeight: CGFloat = 14
  static let stackSpacing: CGFloat = 2
}

/// One word or span. Plain filler reserves the same underline + label height as a marked span
/// so every line keeps a uniform rhythm and the baselines stay aligned.
private struct SentencePiece: View {
  let piece: SentenceDisplayPiece
  let isSelected: Bool
  let onTap: () -> Void

  @State private var hovering = false

  private var segment: SentenceSegment? { piece.segment }
  private var isKeyTerm: Bool { piece.keyTerm != nil }

  var body: some View {
    VStack(spacing: SentenceMetrics.stackSpacing) {
      Text(piece.text)
        .font(.system(size: SentenceMetrics.glyph, weight: isKeyTerm ? .semibold : .regular))
        .foregroundStyle(VocraTheme.ink900)
        .fixedSize()
        .padding(.horizontal, piece.isExplainable ? 2 : 0)
        .padding(.bottom, SentenceMetrics.underlinePad)
        .background(highlight, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(alignment: .bottom) { underline }

      if let segment {
        Text(segment.labelZh)
          .font(.system(size: SentenceMetrics.labelSize, weight: .semibold))
          .foregroundStyle(segment.color.vocraInk)
          .lineLimit(1)
          .fixedSize()
          .frame(height: SentenceMetrics.labelHeight)
          .opacity(isSelected || hovering ? 1 : 0.78)
      } else {
        Color.clear.frame(height: SentenceMetrics.labelHeight)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
    .onHover { hovering = $0 && piece.isExplainable }
    .accessibilityAddTraits(piece.isExplainable ? .isButton : [])
    .accessibilityLabel(accessibilityLabel)
  }

  /// Selected wins over hover; a key word keeps a permanent soft wash so it reads as
  /// "worth learning" even before anything is tapped.
  private var highlight: Color {
    if isSelected { return (segment?.color.vocraColor ?? VocraTheme.accent).opacity(0.24) }
    if hovering { return (segment?.color.vocraColor ?? VocraTheme.accent).opacity(0.13) }
    if isKeyTerm { return VocraTheme.roleAdverbial.opacity(0.16) }
    return .clear
  }

  @ViewBuilder
  private var underline: some View {
    if let segment {
      RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        .fill(segment.color.vocraColor)
        .frame(height: isSelected ? SentenceMetrics.barHeight + 1 : SentenceMetrics.barHeight)
    } else if isKeyTerm {
      // Key words with no grammatical role of their own still need a visible affordance.
      RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        .fill(VocraTheme.roleAdverbialInk.opacity(isSelected ? 0.9 : 0.55))
        .frame(height: 2)
    }
  }

  private var accessibilityLabel: String {
    var parts = [piece.text]
    if let segment { parts.append(segment.labelZh) }
    if piece.keyTerm != nil { parts.append("重点词") }
    return parts.joined(separator: "，")
  }
}

// MARK: - The inline explanation

/// The card that opens beneath the tapped span: what the span does grammatically, and — when
/// it is also a key word — what it means, plus the button that files it in the notebook.
private struct SentenceInlineCard: View {
  let piece: SentenceDisplayPiece
  let saved: Bool
  let onSave: ((KeyVocabularyItem) -> Void)?

  private var accent: Color {
    piece.segment?.color.vocraColor ?? VocraTheme.roleAdverbial
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      if let segment = piece.segment {
        HStack(spacing: 7) {
          Text(segment.labelZh)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(segment.color.vocraInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(segment.color.vocraColor.opacity(0.2), in: Capsule())
          Text(piece.text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(VocraTheme.ink700)
            .lineLimit(2)
          Spacer(minLength: 0)
        }
        Text(grammarNote(for: segment))
          .font(.system(size: 12.5))
          .foregroundStyle(VocraTheme.ink700)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let term = piece.keyTerm {
        if piece.segment != nil {
          Rectangle().fill(VocraTheme.hairline).frame(height: 1)
        }
        HStack(alignment: .firstTextBaseline, spacing: 9) {
          Text(term.term)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(VocraTheme.ink900)
          Text(term.meaning)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(VocraTheme.accentInk)
          Spacer(minLength: 0)
          SpeakerButton(text: term.term, size: 12)
          if let onSave {
            SaveTermButton(saved: saved) { onSave(term) }
          }
        }
        if !term.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(term.note)
            .font(.system(size: 12.5))
            .foregroundStyle(VocraTheme.ink500)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .padding(.horizontal, 13)
    .padding(.vertical, 11)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(accent)
        .frame(width: 3)
        .padding(.vertical, 3)
    }
    .textSelection(.enabled)
  }

  private func grammarNote(for segment: SentenceSegment) -> String {
    let note = segment.note.trimmingCharacters(in: .whitespacesAndNewlines)
    return note.isEmpty ? roleGrammarNote(for: segment) : note
  }
}

// MARK: - Layout

/// Wraps the sentence into rows and, when a span is selected, drops its explanation card onto
/// its own full-width row **directly beneath the row that span sits on**.
///
/// A plain `VStack` of rows can't do this: the wrapping is only known at layout time, after
/// every word has been measured, so the row a given span lands on isn't knowable in the view
/// body. Hence a custom `Layout` — it measures the words, decides the rows, and then knows
/// exactly which one to interrupt.
///
/// The card is always the final subview and is only present when `expandedIndex` is set.
struct InlineExpansionFlow: Layout {
  var spacing: CGFloat = 5
  var rowSpacing: CGFloat = 8
  /// Breathing room above and below the inserted card.
  var cardSpacing: CGFloat = 9
  /// Index of the selected span, or nil when nothing is expanded.
  var expandedIndex: Int?

  private struct Resolved {
    var rows: [[Int]] = []
    var rowHeights: [CGFloat] = []
    /// Row index the card is inserted after.
    var cardRow: Int?
    var cardHeight: CGFloat = 0
    var height: CGFloat = 0
    var width: CGFloat = 0
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .greatestFiniteMagnitude
    let resolved = resolve(subviews: subviews, maxWidth: maxWidth)
    return CGSize(width: proposal.width ?? resolved.width, height: resolved.height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let maxWidth = proposal.width ?? bounds.width
    let resolved = resolve(subviews: subviews, maxWidth: maxWidth)
    var y = bounds.minY

    for (rowIndex, row) in resolved.rows.enumerated() {
      var x = bounds.minX
      for index in row {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(
          at: CGPoint(x: x, y: y),
          anchor: .topLeading,
          proposal: ProposedViewSize(size)
        )
        x += size.width + spacing
      }
      y += resolved.rowHeights[rowIndex]

      if resolved.cardRow == rowIndex, let cardIndex = cardSubviewIndex(in: subviews) {
        y += cardSpacing
        subviews[cardIndex].place(
          at: CGPoint(x: bounds.minX, y: y),
          anchor: .topLeading,
          proposal: ProposedViewSize(width: maxWidth, height: resolved.cardHeight)
        )
        y += resolved.cardHeight + cardSpacing
      }
      if rowIndex < resolved.rows.count - 1 { y += rowSpacing }
    }
  }

  /// The card, when present, is the last subview. SwiftUI drops the `if let` branch from the
  /// subview list when nothing is selected, so its presence is inferred from `expandedIndex`
  /// *and* an actual extra subview — never from `expandedIndex` alone.
  private func cardSubviewIndex(in subviews: Subviews) -> Int? {
    guard let expandedIndex, expandedIndex < subviews.count - 1 else { return nil }
    return subviews.count - 1
  }

  private func resolve(subviews: Subviews, maxWidth: CGFloat) -> Resolved {
    var resolved = Resolved()
    let cardIndex = cardSubviewIndex(in: subviews)
    let pieceCount = cardIndex ?? subviews.count

    var row: [Int] = []
    var rowWidth: CGFloat = 0
    var rowHeight: CGFloat = 0

    for index in 0..<pieceCount {
      let size = subviews[index].sizeThatFits(.unspecified)
      let candidate = row.isEmpty ? size.width : rowWidth + spacing + size.width
      if !row.isEmpty, candidate > maxWidth {
        resolved.rows.append(row)
        resolved.rowHeights.append(rowHeight)
        resolved.width = max(resolved.width, rowWidth)
        row = [index]
        rowWidth = size.width
        rowHeight = size.height
      } else {
        row.append(index)
        rowWidth = candidate
        rowHeight = max(rowHeight, size.height)
      }
    }
    if !row.isEmpty {
      resolved.rows.append(row)
      resolved.rowHeights.append(rowHeight)
      resolved.width = max(resolved.width, rowWidth)
    }

    resolved.height = resolved.rowHeights.reduce(0, +)
      + CGFloat(max(resolved.rows.count - 1, 0)) * rowSpacing

    if let cardIndex, let expandedIndex {
      resolved.cardRow = resolved.rows.firstIndex { $0.contains(expandedIndex) }
        ?? (resolved.rows.isEmpty ? nil : resolved.rows.count - 1)
      resolved.cardHeight = subviews[cardIndex]
        .sizeThatFits(ProposedViewSize(width: maxWidth, height: nil)).height
      if resolved.cardRow != nil {
        resolved.height += resolved.cardHeight + cardSpacing * 2
      }
    }
    return resolved
  }
}
