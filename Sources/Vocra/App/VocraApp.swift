import SwiftUI

@main
struct VocraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("Vocra", systemImage: "text.magnifyingglass") {
      Button("Open Vocra") {
        NSApp.activate(ignoringOtherApps: true)
      }

      Divider()

      Button("Quit Vocra") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")
    }

    WindowGroup("Vocra", id: "main") {
      RootView()
        .frame(minWidth: 900, minHeight: 620)
    }
  }
}
