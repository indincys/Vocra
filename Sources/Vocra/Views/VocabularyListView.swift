import SwiftUI
import VocraCore

struct VocabularyListView: View {
  let cards: [VocabularyCard]

  var body: some View {
    if cards.isEmpty {
      ContentUnavailableView(
        "No Vocabulary",
        systemImage: "text.book.closed",
        description: Text("Words and terms you collect will appear here.")
      )
    } else {
      List(cards) { card in
        VStack(alignment: .leading, spacing: 4) {
          Text(card.text)
            .font(.headline)
          Text(card.type.rawValue.capitalized)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(card.status.rawValue.capitalized)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}
