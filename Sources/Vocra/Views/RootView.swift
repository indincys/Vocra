import SwiftUI

struct RootView: View {
  let appModel: AppModel
  @State private var selection: MainSection? = .vocabulary

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        ForEach(MainSection.allCases) { section in
          Label(section.title, systemImage: section.systemImage)
            .tag(section)
        }
      }
      .listStyle(.sidebar)
    } detail: {
      detailView(for: selection ?? .vocabulary)
    }
  }

  @ViewBuilder
  private func detailView(for section: MainSection) -> some View {
    switch section {
    case .vocabulary:
      VocabularyListView(cards: appModel.allVocabularyCards)
    case .review:
      ReviewView(cards: appModel.dueCards()) { cardID, rating in
        appModel.applyReview(cardID: cardID, rating: rating)
      }
    case .settings:
      SettingsView()
    }
  }
}

private enum MainSection: String, CaseIterable, Identifiable {
  case vocabulary
  case review
  case settings

  var id: Self { self }

  var title: String {
    switch self {
    case .vocabulary: "Vocabulary"
    case .review: "Review"
    case .settings: "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .vocabulary: "text.book.closed"
    case .review: "rectangle.on.rectangle"
    case .settings: "gearshape"
    }
  }
}
