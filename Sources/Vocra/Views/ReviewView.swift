import SwiftUI
import VocraCore

struct ReviewView: View {
  let cards: [VocabularyCard]
  let onRate: (UUID, ReviewRating) -> Void
  @State private var index = 0
  @State private var showsBack = false

  var body: some View {
    VStack(spacing: 20) {
      if cards.isEmpty || index >= cards.count {
        ContentUnavailableView(
          "No Due Cards",
          systemImage: "checkmark.circle",
          description: Text("Vocabulary due for review will appear here.")
        )
      } else {
        let card = cards[index]

        Button {
          showsBack.toggle()
        } label: {
          VStack(spacing: 16) {
            Text(card.text)
              .font(.largeTitle)
              .fontWeight(.semibold)

            if showsBack {
              Text(renderedMarkdown(card.cardMarkdown))
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(32)
          .frame(maxWidth: 560, minHeight: 320)
        }
        .buttonStyle(.plain)

        HStack {
          reviewButton("Forgot", .forgot, card.id)
          reviewButton("Vague", .vague, card.id)
          reviewButton("Familiar", .familiar, card.id)
          reviewButton("Mastered", .mastered, card.id)
        }
      }
    }
    .padding()
  }

  private func reviewButton(_ title: String, _ rating: ReviewRating, _ cardID: UUID) -> some View {
    Button(title) {
      onRate(cardID, rating)
      showsBack = false
      index += 1
    }
    .buttonStyle(.glass)
  }

  private func renderedMarkdown(_ markdown: String) -> AttributedString {
    (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
  }
}
