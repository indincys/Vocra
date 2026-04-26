import SwiftUI

struct RootView: View {
  let appModel: AppModel

  var body: some View {
    NavigationSplitView {
      List {
        Label("Vocabulary", systemImage: "text.book.closed")
        Label("Review", systemImage: "rectangle.on.rectangle")
        Label("Settings", systemImage: "gearshape")
      }
      .listStyle(.sidebar)
    } detail: {
      VStack(alignment: .leading, spacing: 12) {
        ContentUnavailableView(
          "Vocra",
          systemImage: "sparkle.magnifyingglass",
          description: Text("Use the menu bar or global shortcut to explain selected English text.")
        )

        if let latest = appModel.latestCapturedText {
          Text("Latest: \(latest.cleanedText)")
            .font(.headline)
        }

        if let error = appModel.latestErrorMessage {
          Text(error)
            .foregroundStyle(.red)
            .textSelection(.enabled)
        }

        if !appModel.latestMarkdown.isEmpty {
          ScrollView {
            Text(tryAttributedMarkdown(appModel.latestMarkdown))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding()
    }
  }

  private func tryAttributedMarkdown(_ markdown: String) -> AttributedString {
    (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
  }
}
