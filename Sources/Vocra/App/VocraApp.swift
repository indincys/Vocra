import SwiftUI

@main
struct VocraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.openWindow) private var openWindow
  @State private var appModel = AppModel()

  var body: some Scene {
    MenuBarExtra("Vocra", systemImage: "text.magnifyingglass") {
      Button("Explain Selection") {
        Task { await appModel.handleShortcut() }
      }
      .keyboardShortcut("e")

      Button(appModel.isShortcutPaused ? "Resume Shortcut" : "Pause Shortcut") {
        appModel.pauseShortcutListening(!appModel.isShortcutPaused)
      }

      Button("Check for Updates...") {
        appModel.appUpdater.checkForUpdates()
      }
      .disabled(!appModel.appUpdater.isEnabled)

      Divider()

      Button("Open Vocra") {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
      }

      Divider()

      Button("Quit Vocra") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")
    }

    WindowGroup("Vocra", id: "main") {
      RootView(appModel: appModel)
        .frame(minWidth: 900, minHeight: 620)
        .task {
          appModel.start()
        }
    }

    Settings {
      SettingsView()
    }
  }
}
