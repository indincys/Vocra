import SwiftUI

struct RootView: View {
  var body: some View {
    NavigationSplitView {
      List {
        Label("Vocabulary", systemImage: "text.book.closed")
        Label("Review", systemImage: "rectangle.on.rectangle")
        Label("Settings", systemImage: "gearshape")
      }
      .listStyle(.sidebar)
    } detail: {
      ContentUnavailableView(
        "Vocra",
        systemImage: "sparkle.magnifyingglass",
        description: Text("Use the menu bar or global shortcut to explain selected English text.")
      )
    }
  }
}
