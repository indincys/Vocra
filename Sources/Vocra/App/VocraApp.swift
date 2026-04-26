import SwiftUI

@main
struct VocraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.openWindow) private var openWindow
  @State private var appModel: AppModel
  private let appName: String

  @MainActor
  init() {
    let appModel = AppModel()
    _appModel = State(initialValue: appModel)
    self.appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "Vocra"
    appModel.start()
  }

  var body: some Scene {
    MenuBarExtra(appName, systemImage: "text.magnifyingglass") {
      if let shortcutRegistrationErrorMessage = appModel.shortcutRegistrationErrorMessage {
        Text(shortcutRegistrationErrorMessage)
        Divider()
      }

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

      Button("Open \(appName)") {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
      }

      Divider()

      Button("Quit Vocra") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")
    }

    mainWindowScene

    Settings {
      SettingsView()
    }
  }

  private var mainWindowScene: some Scene {
    appDelegate.openMainWindow = {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }

    return Window(appName, id: "main") {
      RootView(appModel: appModel)
        .frame(minWidth: 900, minHeight: 620)
    }
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)
  }
}
