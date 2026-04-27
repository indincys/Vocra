import SwiftUI
import VocraCore

struct LearningExplanationView: View {
  let document: LearningExplanationDocument

  var body: some View {
    if document.mode == .sentence, let analysis = document.sentenceAnalysis {
      SentenceLearningView(analysis: analysis)
    } else if (document.mode == .word || document.mode == .phrase), let explanation = document.wordExplanation {
      WordLearningView(explanation: explanation)
    } else if let vocabularyCard = document.vocabularyCard,
              document.sentenceAnalysis == nil,
              document.wordExplanation == nil {
      VocabularyCardLearningView(card: vocabularyCard)
    } else {
      fallback
    }
  }

  private var fallback: some View {
    LearningSection(title: "Explanation unavailable", systemImage: "exclamationmark.triangle") {
      Text("Vocra could not find structured content for this explanation.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
  }
}

struct LearningSection<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.headline)
        .labelStyle(.titleAndIcon)

      content
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

extension LearningColorToken {
  var swiftUIColor: Color {
    switch self {
    case .blue:
      .blue
    case .green:
      .green
    case .orange:
      .orange
    case .purple:
      .purple
    case .pink:
      .pink
    case .neutral:
      .secondary
    }
  }
}

struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  var rowSpacing: CGFloat = 8

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    let rows = rows(for: subviews, proposal: proposal)
    let height = rows.reduce(CGFloat.zero) { partial, row in
      partial + row.height
    } + CGFloat(max(rows.count - 1, 0)) * rowSpacing
    let width = proposal.width ?? rows.map(\.width).max() ?? 0

    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0
    let maxWidth = proposal.width ?? bounds.width

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > bounds.minX, x + size.width > bounds.minX + maxWidth {
        x = bounds.minX
        y += rowHeight + rowSpacing
        rowHeight = 0
      }

      subview.place(
        at: CGPoint(x: x, y: y),
        anchor: .topLeading,
        proposal: ProposedViewSize(size)
      )
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }

  private func rows(for subviews: Subviews, proposal: ProposedViewSize) -> [FlowRow] {
    let maxWidth = proposal.width ?? .infinity
    var rows: [FlowRow] = []
    var current = FlowRow()

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      let proposedWidth = current.width == 0 ? size.width : current.width + spacing + size.width

      if proposedWidth > maxWidth, current.width > 0 {
        rows.append(current)
        current = FlowRow(width: size.width, height: size.height)
      } else {
        current.width = proposedWidth
        current.height = max(current.height, size.height)
      }
    }

    if current.width > 0 {
      rows.append(current)
    }

    return rows
  }
}

private struct FlowRow {
  var width: CGFloat = 0
  var height: CGFloat = 0
}
