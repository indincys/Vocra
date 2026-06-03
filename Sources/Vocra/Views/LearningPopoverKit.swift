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

/// The parsed sentence rendered as colored, thickly-underlined role chunks plus
/// a compact legend. Hovering any chunk pops a bubble explaining that component.
struct RoleUnderlinedSentence: View {
  let segments: [SentenceSegment]
  @State private var hoveredID: String?

  private var usedRoles: [SentenceSegment] {
    var seen = Set<String>()
    return segments.filter { seen.insert($0.labelZh).inserted }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      FlowLayout(spacing: 5, rowSpacing: 14) {
        ForEach(segments) { segment in
          SegmentChunk(segment: segment, hoveredID: $hoveredID)
        }
      }
      if usedRoles.count > 1 {
        FlowLayout(spacing: 12, rowSpacing: 7) {
          ForEach(usedRoles) { segment in
            HStack(spacing: 5) {
              RoundedRectangle(cornerRadius: 1).fill(segment.color.vocraColor).frame(width: 15, height: 2.5)
              Text(segment.labelZh).font(.system(size: 11)).foregroundStyle(VocraTheme.ink500)
            }
          }
        }
      }
    }
  }
}

private struct SegmentChunk: View {
  let segment: SentenceSegment
  @Binding var hoveredID: String?

  var body: some View {
    Text(segment.text)
      .font(.system(size: 17))
      .foregroundStyle(VocraTheme.ink900)
      .padding(.horizontal, 2)
      .padding(.bottom, 3)
      .background(
        hoveredID == segment.id ? segment.color.vocraColor.opacity(0.16) : .clear,
        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
      )
      .overlay(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(segment.color.vocraColor)
          .frame(height: 3)
      }
      .onHover { hovering in
        if hovering { hoveredID = segment.id }
        else if hoveredID == segment.id { hoveredID = nil }
      }
      .popover(
        isPresented: Binding(
          get: { hoveredID == segment.id },
          set: { presented in if !presented, hoveredID == segment.id { hoveredID = nil } }
        ),
        arrowEdge: .top
      ) {
        SegmentTooltip(segment: segment).environment(\.colorScheme, .light)
      }
  }
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
