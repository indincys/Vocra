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
    MenuBarExtra {
      if let shortcutRegistrationErrorMessage = appModel.shortcutRegistrationErrorMessage {
        Text(shortcutRegistrationErrorMessage)
        Divider()
      }
      if let databaseErrorMessage = appModel.databaseErrorMessage {
        Text(databaseErrorMessage)
        Divider()
      }

      Button("查词解析") {
        Task { await appModel.handleShortcut() }
      }
      .keyboardShortcut("e")

      Button(appModel.isShortcutPaused ? "恢复划词监听" : "暂停划词监听") {
        appModel.pauseShortcutListening(!appModel.isShortcutPaused)
      }

      Button("检查更新…") {
        appModel.appUpdater.checkForUpdates()
      }
      .disabled(!appModel.appUpdater.isEnabled)

      Divider()

      Button("打开 \(appName)") {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
      }

      Divider()

      Button("退出 Vocra") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")
    } label: {
      // The menu-bar item is always mounted, so its onAppear is a reliable place to bridge
      // SwiftUI's openWindow to the AppDelegate (used for dock-reopen) — instead of doing it
      // as a side effect inside a computed Scene property.
      Image(systemName: "text.magnifyingglass")
        .onAppear {
          appDelegate.openMainWindow = {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
          }
        }
    }

    mainWindowScene

    Settings {
      SettingsView()
    }
  }

  private var mainWindowScene: some Scene {
    Window(appName, id: "main") {
      RootView(appModel: appModel)
        .frame(minWidth: 900, minHeight: 620)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)
  }
}
