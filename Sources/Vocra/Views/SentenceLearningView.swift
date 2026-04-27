import SwiftUI
import VocraCore

struct SentenceLearningView: View {
  let analysis: SentenceAnalysis

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        Text(analysis.headline.title)
          .font(.title3.weight(.semibold))
          .textSelection(.enabled)

        if !analysis.headline.subtitle.isEmpty {
          Text(analysis.headline.subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }

      sentenceSegments
      structureBreakdown
      relationshipDiagram
      logicSummary
      translation
      keyVocabulary
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var sentenceSegments: some View {
    LearningSection(title: "Sentence", systemImage: "text.quote") {
      FlowLayout(spacing: 8, rowSpacing: 8) {
        ForEach(analysis.sentence.segments) { segment in
          VStack(alignment: .leading, spacing: 4) {
            Text(segment.text)
              .font(.body.weight(.medium))
              .fixedSize(horizontal: false, vertical: true)

            Text("\(segment.labelEn) · \(segment.labelZh)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .textSelection(.enabled)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(
            segment.color.swiftUIColor.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .stroke(segment.color.swiftUIColor.opacity(0.28), lineWidth: 1)
          }
        }
      }
    }
  }

  private var structureBreakdown: some View {
    LearningSection(title: analysis.structureBreakdown.title, systemImage: "list.bullet.indent") {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(analysis.structureBreakdown.items) { item in
          StructureItemView(item: item, depth: 0)
        }
      }
    }
  }

  private var relationshipDiagram: some View {
    LearningSection(title: "Relationships", systemImage: "arrow.triangle.branch") {
      if analysis.relationshipDiagram.edges.isEmpty {
        Text("No relationship links were included.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(analysis.relationshipDiagram.edges.enumerated()), id: \.offset) { _, edge in
            RelationshipEdgeView(
              edge: edge,
              nodes: Dictionary(uniqueKeysWithValues: analysis.relationshipDiagram.nodes.map { ($0.id, $0) })
            )
          }
        }
      }
    }
  }

  private var logicSummary: some View {
    LearningSection(title: analysis.logicSummary.title, systemImage: "lightbulb") {
      VStack(alignment: .leading, spacing: 8) {
        Text(analysis.logicSummary.coreMeaning)
          .font(.body)
          .textSelection(.enabled)

        ForEach(Array(analysis.logicSummary.points.enumerated()), id: \.offset) { _, point in
          Label(point, systemImage: "checkmark.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }
    }
  }

  private var translation: some View {
    LearningSection(title: analysis.translation.title, systemImage: "character.book.closed") {
      Text(analysis.translation.text)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
  }

  @ViewBuilder
  private var keyVocabulary: some View {
    if !analysis.keyVocabulary.isEmpty {
      LearningSection(title: "Key Vocabulary", systemImage: "text.book.closed") {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(Array(analysis.keyVocabulary.enumerated()), id: \.offset) { index, item in
            VStack(alignment: .leading, spacing: 3) {
              Text(item.term)
                .font(.callout.weight(.semibold))
              Text(item.meaning)
                .font(.callout)
              if !item.note.isEmpty {
                Text(item.note)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .textSelection(.enabled)

            if index < analysis.keyVocabulary.count - 1 {
              Divider().opacity(0.35)
            }
          }
        }
      }
    }
  }
}

private struct StructureItemView: View {
  let item: StructureItem
  let depth: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .top, spacing: 8) {
        Circle()
          .fill(.secondary.opacity(0.45))
          .frame(width: 6, height: 6)
          .padding(.top, 7)

        VStack(alignment: .leading, spacing: 3) {
          Text(item.text)
            .font(.callout.weight(.medium))
          Text("\(item.labelEn) · \(item.labelZh)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .textSelection(.enabled)
      }
      .padding(.leading, CGFloat(depth) * 14)

      ForEach(item.children) { child in
        StructureItemView(item: child, depth: depth + 1)
      }
    }
  }
}

private struct RelationshipEdgeView: View {
  let edge: RelationshipEdge
  let nodes: [String: RelationshipNode]

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(nodes[edge.from]?.title ?? edge.from)
          .font(.callout.weight(.semibold))
        Text(nodes[edge.from]?.text ?? edge.from)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Image(systemName: "arrow.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 3)

      VStack(alignment: .leading, spacing: 2) {
        Text(nodes[edge.to]?.title ?? edge.to)
          .font(.callout.weight(.semibold))
        Text(nodes[edge.to]?.text ?? edge.to)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      Text("\(edge.labelEn) · \(edge.labelZh)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .textSelection(.enabled)
  }
}
