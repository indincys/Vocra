import SwiftUI
import VocraCore

struct SentenceLearningView: View {
  let analysis: SentenceAnalysis

  private var displayedSegments: [SentenceSegment] {
    if !analysis.sentence.segments.isEmpty {
      return analysis.sentence.segments
    }
    return [
      SentenceSegment(
        id: "whole-sentence",
        text: analysis.sentence.text,
        role: "sentence",
        labelZh: "整句",
        labelEn: "Sentence",
        color: .blue
      )
    ]
  }

  var body: some View {
    VStack(spacing: 16) {
      headline
      SentenceRibbon(segments: displayedSegments)
      structureBreakdown
      relationshipAndLogic
      translation
      keyVocabulary
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .top)
    .foregroundStyle(.black.opacity(0.88))
    .background {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.white.opacity(0.96))
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.black.opacity(0.12), lineWidth: 1)
    }
    .environment(\.colorScheme, .light)
    .textSelection(.enabled)
  }

  private var headline: some View {
    VStack(spacing: 5) {
      Text(analysis.headline.title)
        .font(.system(size: 34, weight: .heavy, design: .rounded))
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.75)

      HStack(spacing: 12) {
        Rectangle()
          .fill(Color.gray.opacity(0.35))
          .frame(width: 72, height: 1)
        Circle()
          .fill(Color.gray.opacity(0.55))
          .frame(width: 6, height: 6)
        Text(analysis.headline.subtitle.isEmpty ? "Sentence Analysis" : analysis.headline.subtitle)
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.gray)
        Circle()
          .fill(Color.gray.opacity(0.55))
          .frame(width: 6, height: 6)
        Rectangle()
          .fill(Color.gray.opacity(0.35))
          .frame(width: 72, height: 1)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var structureBreakdown: some View {
    InfographicSection(
      title: analysis.structureBreakdown.title,
      icon: "list.bullet.indent",
      tint: .orange,
      dashedBorder: true
    ) {
      if analysis.structureBreakdown.items.isEmpty {
        Text(analysis.sentence.text)
          .font(.body.weight(.semibold))
          .foregroundStyle(Color.orange)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(analysis.structureBreakdown.items) { item in
            InfographicStructureItemView(item: item, depth: 0)
          }
        }
      }
    }
  }

  private var relationshipAndLogic: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 14) {
        relationshipDiagram
        logicSummary
      }

      VStack(spacing: 14) {
        relationshipDiagram
        logicSummary
      }
    }
  }

  private var relationshipDiagram: some View {
    InfographicSection(title: "句子关系图示", icon: "link", tint: .blue) {
      RelationshipDiagramView(diagram: analysis.relationshipDiagram)
    }
  }

  private var logicSummary: some View {
    InfographicSection(title: analysis.logicSummary.title, icon: "lightbulb", tint: .orange) {
      VStack(alignment: .leading, spacing: 10) {
        Text(analysis.logicSummary.coreMeaning)
          .font(.body.weight(.semibold))
          .foregroundStyle(Color.black.opacity(0.86))

        ForEach(Array(analysis.logicSummary.points.enumerated()), id: \.offset) { _, point in
          HStack(alignment: .top, spacing: 8) {
            Circle()
              .fill(Color.black.opacity(0.75))
              .frame(width: 5, height: 5)
              .padding(.top, 7)
            Text(point)
              .font(.callout)
              .foregroundStyle(Color.black.opacity(0.72))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
  }

  private var translation: some View {
    InfographicSection(title: analysis.translation.title, icon: "message.fill", tint: .green) {
      Text(analysis.translation.text)
        .font(.title3.weight(.semibold))
        .foregroundStyle(Color.black.opacity(0.86))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var keyVocabulary: some View {
    if !analysis.keyVocabulary.isEmpty {
      InfographicSection(title: "重点词汇讲解", icon: "book.closed", tint: .purple) {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
          ForEach(Array(analysis.keyVocabulary.enumerated()), id: \.offset) { index, item in
            VocabularyTile(index: index + 1, item: item)
          }
        }
      }
    }
  }
}

private struct SentenceRibbon: View {
  let segments: [SentenceSegment]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      FlowLayout(spacing: 10, rowSpacing: 14) {
        ForEach(segments) { segment in
          SentenceSegmentToken(segment: segment)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.gray.opacity(0.28), lineWidth: 1)
    }
  }
}

private struct SentenceSegmentToken: View {
  let segment: SentenceSegment

  var body: some View {
    VStack(spacing: 6) {
      Text(segment.text)
        .font(.system(size: tokenFontSize, weight: .heavy, design: .rounded))
        .foregroundStyle(segment.color.infographicColor)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: 2) {
        Text(segment.labelZh)
          .font(.caption.weight(.bold))
        Text(segment.labelEn)
          .font(.caption2.weight(.medium))
      }
      .foregroundStyle(segment.color.infographicColor.opacity(0.9))
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .background(segment.color.infographicColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(segment.color.infographicColor.opacity(0.25), lineWidth: 1)
      }
    }
    .frame(minWidth: 82, idealWidth: idealWidth, maxWidth: 240)
  }

  private var idealWidth: CGFloat {
    min(max(CGFloat(segment.text.count) * 9, 96), 240)
  }

  private var tokenFontSize: CGFloat {
    segment.text.count > 26 ? 16 : 21
  }
}

private struct InfographicSection<Content: View>: View {
  let title: String
  let icon: String
  let tint: Color
  var dashedBorder = false
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label {
        Text(title)
          .font(.headline.weight(.bold))
      } icon: {
        Image(systemName: icon)
          .font(.title3.weight(.bold))
          .foregroundStyle(tint)
      }

      content
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(
          tint.opacity(dashedBorder ? 0.42 : 0.18),
          style: StrokeStyle(lineWidth: 1, dash: dashedBorder ? [5, 4] : [])
        )
    }
  }
}

private struct InfographicStructureItemView: View {
  let item: StructureItem
  let depth: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Text(item.text)
          .font(.callout.weight(.bold))
          .foregroundStyle(Color.black.opacity(0.84))
          .fixedSize(horizontal: false, vertical: true)

        Spacer(minLength: 8)

        VStack(alignment: .trailing, spacing: 2) {
          Text(item.labelZh)
            .font(.caption.weight(.bold))
          Text(item.labelEn)
            .font(.caption2.weight(.medium))
        }
        .foregroundStyle(Color.orange)
        .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.leading, CGFloat(depth) * 16)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(Color.orange.opacity(0.18), lineWidth: 1)
      }

      ForEach(item.children) { child in
        InfographicStructureItemView(item: child, depth: depth + 1)
      }
    }
  }
}

private struct RelationshipDiagramView: View {
  let diagram: RelationshipDiagram

  private var nodes: [String: RelationshipNode] {
    diagram.nodes.reduce(into: [:]) { partial, node in
      partial[node.id] = node
    }
  }

  var body: some View {
    if diagram.edges.isEmpty {
      FlowLayout(spacing: 10, rowSpacing: 10) {
        ForEach(diagram.nodes) { node in
          RelationshipNodeCard(node: node)
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(diagram.edges.enumerated()), id: \.offset) { _, edge in
          RelationshipEdgeRow(edge: edge, nodes: nodes)
        }
      }
    }
  }
}

private struct RelationshipEdgeRow: View {
  let edge: RelationshipEdge
  let nodes: [String: RelationshipNode]

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        RelationshipNodeCard(node: nodes[edge.from] ?? RelationshipNode(id: edge.from, title: edge.from, text: edge.from))
        VStack(spacing: 4) {
          Image(systemName: "arrow.right")
            .font(.headline.weight(.bold))
          Text(edge.labelZh)
            .font(.caption.weight(.semibold))
          Text(edge.labelEn)
            .font(.caption2)
        }
        .foregroundStyle(Color.blue.opacity(0.9))
        RelationshipNodeCard(node: nodes[edge.to] ?? RelationshipNode(id: edge.to, title: edge.to, text: edge.to))
      }

      VStack(alignment: .leading, spacing: 8) {
        RelationshipNodeCard(node: nodes[edge.from] ?? RelationshipNode(id: edge.from, title: edge.from, text: edge.from))
        HStack(spacing: 8) {
          Image(systemName: "arrow.down")
          Text("\(edge.labelZh) / \(edge.labelEn)")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.blue)
        RelationshipNodeCard(node: nodes[edge.to] ?? RelationshipNode(id: edge.to, title: edge.to, text: edge.to))
      }
    }
  }
}

private struct RelationshipNodeCard: View {
  let node: RelationshipNode

  var body: some View {
    VStack(spacing: 5) {
      Text(node.title)
        .font(.callout.weight(.bold))
        .foregroundStyle(Color.blue)
      Text(node.text)
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundStyle(Color.black.opacity(0.82))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(minWidth: 150, maxWidth: 240)
    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.blue.opacity(0.28), lineWidth: 1)
    }
  }
}

private struct VocabularyTile: View {
  let index: Int
  let item: KeyVocabularyItem

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text("\(index)")
          .font(.headline.weight(.heavy))
          .foregroundStyle(.white)
          .frame(width: 26, height: 26)
          .background(Color.purple, in: Circle())

        Text(item.term)
          .font(.headline.weight(.bold))
          .foregroundStyle(Color.purple)
          .lineLimit(2)
      }

      Text(item.meaning)
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.black.opacity(0.78))

      if !item.note.isEmpty {
        Text(item.note)
          .font(.caption)
          .foregroundStyle(Color.black.opacity(0.58))
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(Color.purple.opacity(0.18), lineWidth: 1)
    }
  }
}

private extension LearningColorToken {
  var infographicColor: Color {
    switch self {
    case .blue:
      Color(red: 0.05, green: 0.35, blue: 0.82)
    case .green:
      Color(red: 0.02, green: 0.48, blue: 0.18)
    case .orange:
      Color(red: 0.95, green: 0.32, blue: 0.02)
    case .purple:
      Color(red: 0.37, green: 0.16, blue: 0.82)
    case .pink:
      Color(red: 0.93, green: 0.07, blue: 0.34)
    case .neutral:
      Color(red: 0.32, green: 0.36, blue: 0.42)
    }
  }
}
