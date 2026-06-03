import SwiftUI
import VocraCore

struct SentenceLearningView: View {
  let analysis: SentenceAnalysis
  var onSaveVocabulary: VocabularySaveAction? = nil
  @State private var savedTerms: Set<String> = []

  private var nodesByID: [String: RelationshipNode] {
    analysis.relationshipDiagram.nodes.reduce(into: [:]) { $0[$1.id] = $1 }
  }

  var body: some View {
    VStack(spacing: 0) {
      overview
      backbone
      relationships
      logic
      translation
      keyVocabulary
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .textSelection(.enabled)
  }

  private var overview: some View {
    Group {
      if analysis.sentence.segments.isEmpty {
        Text(analysis.sentence.text)
          .font(.system(size: 17))
          .foregroundStyle(VocraTheme.ink900)
          .lineSpacing(5)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        RoleUnderlinedSentence(segments: analysis.sentence.segments)
      }
    }
    .padding(18)
  }

  @ViewBuilder
  private var backbone: some View {
    if !analysis.headline.title.isEmpty || !analysis.structureBreakdown.items.isEmpty {
      PopSection(icon: "scissors", title: "抓主干", hint: analysis.headline.subtitle.isEmpty ? nil : analysis.headline.subtitle) {
        PopInset(tint: VocraTheme.accentSoft) {
          VStack(alignment: .leading, spacing: 8) {
            if !analysis.headline.title.isEmpty {
              Text(analysis.headline.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VocraTheme.ink900)
            }
            ForEach(analysis.structureBreakdown.items) { item in
              StructureRow(item: item, depth: 0)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var relationships: some View {
    if !analysis.relationshipDiagram.edges.isEmpty {
      PopSection(icon: "link", title: "句子关系", hint: "拆长句的关节") {
        VStack(alignment: .leading, spacing: 9) {
          ForEach(Array(analysis.relationshipDiagram.edges.enumerated()), id: \.offset) { _, edge in
            HStack(alignment: .firstTextBaseline, spacing: 7) {
              Text(nodeTitle(edge.from))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VocraTheme.ink900)
              Text(edge.labelZh)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VocraTheme.accentInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(VocraTheme.accentSoft, in: Capsule())
              Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(VocraTheme.ink400)
              Text(nodeTitle(edge.to))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VocraTheme.ink900)
              Spacer(minLength: 0)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var logic: some View {
    if !analysis.logicSummary.points.isEmpty || !analysis.logicSummary.coreMeaning.isEmpty {
      PopSection(icon: "sparkles", title: analysis.logicSummary.title.isEmpty ? "句意解析" : analysis.logicSummary.title, hint: "跟着步骤读懂它") {
        VStack(alignment: .leading, spacing: 11) {
          if !analysis.logicSummary.coreMeaning.isEmpty {
            Text(analysis.logicSummary.coreMeaning)
              .font(.system(size: 13.5))
              .foregroundStyle(VocraTheme.ink700)
              .lineSpacing(2)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          ForEach(Array(analysis.logicSummary.points.enumerated()), id: \.offset) { index, point in
            HStack(alignment: .top, spacing: 11) {
              PopNumber(number: index + 1)
              Text(point)
                .font(.system(size: 13.5))
                .foregroundStyle(VocraTheme.ink700)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var translation: some View {
    if !analysis.translation.text.isEmpty {
      PopSection(icon: "text.bubble", title: analysis.translation.title.isEmpty ? "整句译文" : analysis.translation.title) {
        Text(analysis.translation.text)
          .font(.system(size: 14.5))
          .foregroundStyle(VocraTheme.ink700)
          .lineSpacing(4)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  @ViewBuilder
  private var keyVocabulary: some View {
    if !analysis.keyVocabulary.isEmpty {
      PopSection(icon: "star", title: "重点单词 / 词组", hint: onSaveVocabulary == nil ? nil : "点 + 加入生词本") {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(Array(analysis.keyVocabulary.enumerated()), id: \.offset) { _, item in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
              Text(item.term)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VocraTheme.ink900)
              Text(item.meaning)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(VocraTheme.accentInk)
              if !item.note.isEmpty {
                Text(item.note)
                  .font(.system(size: 12))
                  .foregroundStyle(VocraTheme.ink400)
                  .lineLimit(1)
              }
              Spacer(minLength: 0)
              SpeakerButton(text: item.term, size: 13)
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
            .padding(.vertical, 5)
          }
        }
      }
    }
  }

  private func nodeTitle(_ id: String) -> String {
    nodesByID[id]?.title ?? id
  }
}

private struct StructureRow: View {
  let item: StructureItem
  let depth: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 8) {
        Text(item.text)
          .font(.system(size: 13.5))
          .foregroundStyle(VocraTheme.ink700)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        Text(item.labelZh)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(VocraTheme.accentInk)
          .fixedSize()
      }
      .padding(.leading, CGFloat(depth) * 14)

      ForEach(item.children) { child in
        StructureRow(item: child, depth: depth + 1)
      }
    }
  }
}
