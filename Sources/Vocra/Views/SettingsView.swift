import AppKit
import Carbon
import SwiftUI
import VocraCore

struct SettingsView: View {
  private let settingsStore = UserDefaultsSettingsStore()
  private let apiKeyStore = KeychainAPIKeyStore()
  private let promptStore = UserDefaultsPromptStore()
  private let reminderService = ReviewReminderService()

  @State private var baseURL = APIConfiguration.default.baseURL.absoluteString
  @State private var model = APIConfiguration.default.model
  @State private var timeout = APIConfiguration.default.timeoutSeconds
  @State private var apiKey = ""
  @State private var isTestingAPI = false
  @State private var wordPrompt = ""
  @State private var phrasePrompt = ""
  @State private var sentencePrompt = ""
  @State private var cardPrompt = ""
  @State private var keyboardShortcut = VocraCore.KeyboardShortcut.defaultShortcut
  @State private var isRecordingShortcut = false
  @State private var statusMessage = ""
  @AppStorage("vocra.dailyReminderEnabled") private var dailyReminderEnabled = false
  @AppStorage("vocra.reminderHour") private var reminderHour = 9
  @AppStorage("vocra.reminderMinute") private var reminderMinute = 0

  var body: some View {
    Form {
      Section("API") {
        TextField("Base URL", text: $baseURL)
        TextField("Model", text: $model)
        SecureField("API Key", text: $apiKey)
        Stepper("Timeout: \(Int(timeout)) seconds", value: $timeout, in: 5...120, step: 5)
        HStack {
          Button("Save API Settings", action: saveAPISettings)
          Button(isTestingAPI ? "Testing API..." : "测试API") {
            Task {
              await testAPIConnection()
            }
          }
          .disabled(isTestingAPI)
        }
      }

      Section("Prompts") {
        promptEditor("Word Explanation", text: $wordPrompt)
        promptEditor("Term Explanation", text: $phrasePrompt)
        promptEditor("Sentence Explanation", text: $sentencePrompt)
        promptEditor("Vocabulary Card", text: $cardPrompt)
        Button("Save Prompts", action: savePrompts)
      }

      Section("Shortcut") {
        HStack {
          Text("Explain Selection")
          Spacer()
          Text(keyboardShortcut.displayString)
            .font(.body.monospaced())
            .foregroundStyle(.secondary)
        }

        HStack {
          Button(isRecordingShortcut ? "Press New Shortcut..." : "Record Shortcut") {
            isRecordingShortcut.toggle()
          }

          Button("Reset to Default") {
            keyboardShortcut = .defaultShortcut
            saveKeyboardShortcut()
          }
        }

        if isRecordingShortcut {
          Text("Press a key combination with Command, Option, Control, or Shift. Press Esc to cancel.")
            .foregroundStyle(.secondary)
        }

        ShortcutRecorderView(isRecording: $isRecordingShortcut) { shortcut in
          keyboardShortcut = shortcut
          isRecordingShortcut = false
          saveKeyboardShortcut()
        }
        .frame(width: 1, height: 1)
        .accessibilityHidden(true)
      }

      Section("Review") {
        Toggle("Daily Reminder", isOn: $dailyReminderEnabled)
        DatePicker("Daily Reminder Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
        Button(dailyReminderEnabled ? "Schedule Daily Reminder" : "Disable Daily Reminder") {
          Task {
            await saveReminderPreference()
          }
        }
      }

      if !statusMessage.isEmpty {
        Text(statusMessage)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(minWidth: 620, minHeight: 720)
    .onAppear(perform: load)
  }

  private func promptEditor(_ title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.headline)
      TextEditor(text: text)
        .font(.body.monospaced())
        .frame(minHeight: 100)
    }
  }

  private func load() {
    let configuration = settingsStore.loadAPIConfiguration()
    baseURL = configuration.baseURL.absoluteString
    model = configuration.model
    timeout = configuration.timeoutSeconds
    apiKey = (try? apiKeyStore.readAPIKey()) ?? ""
    wordPrompt = promptStore.template(for: .wordExplanation)?.body ?? ""
    phrasePrompt = promptStore.template(for: .phraseExplanation)?.body ?? ""
    sentencePrompt = promptStore.template(for: .sentenceExplanation)?.body ?? ""
    cardPrompt = promptStore.template(for: .vocabularyCard)?.body ?? ""
    keyboardShortcut = settingsStore.loadKeyboardShortcut()
  }

  private func saveAPISettings() {
    guard let configuration = currentAPIConfiguration() else {
      statusMessage = "Base URL is invalid."
      return
    }

    settingsStore.saveAPIConfiguration(configuration)

    do {
      if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        try apiKeyStore.deleteAPIKey()
      } else {
        try apiKeyStore.saveAPIKey(apiKey)
      }
      statusMessage = "API settings saved."
    } catch {
      statusMessage = "API key save failed: \(error)"
    }
  }

  @MainActor
  private func testAPIConnection() async {
    guard let configuration = currentAPIConfiguration() else {
      statusMessage = "Base URL is invalid."
      return
    }

    isTestingAPI = true
    statusMessage = "Testing API connection..."
    defer { isTestingAPI = false }

    do {
      try await APIConnectionTester().test(configuration: configuration, apiKey: apiKey)
      statusMessage = "API connection succeeded."
    } catch {
      statusMessage = "API connection failed: \(error)"
    }
  }

  private func savePrompts() {
    promptStore.save(PromptTemplate(kind: .wordExplanation, body: wordPrompt))
    promptStore.save(PromptTemplate(kind: .phraseExplanation, body: phrasePrompt))
    promptStore.save(PromptTemplate(kind: .sentenceExplanation, body: sentencePrompt))
    promptStore.save(PromptTemplate(kind: .vocabularyCard, body: cardPrompt))
    statusMessage = "Prompts saved."
  }

  private func saveKeyboardShortcut() {
    settingsStore.saveKeyboardShortcut(keyboardShortcut)
    NotificationCenter.default.post(
      name: .vocraKeyboardShortcutDidChange,
      object: nil,
      userInfo: [VocraNotificationUserInfoKey.keyboardShortcut: keyboardShortcut]
    )
    statusMessage = "Shortcut saved: \(keyboardShortcut.displayString)."
  }

  private func currentAPIConfiguration() -> APIConfiguration? {
    guard let url = URL(string: baseURL) else { return nil }
    return APIConfiguration(
      baseURL: url,
      model: model,
      timeoutSeconds: timeout
    )
  }

  private var reminderTimeBinding: Binding<Date> {
    Binding {
      Calendar.current.date(from: DateComponents(
        year: 2000,
        month: 1,
        day: 1,
        hour: reminderHour,
        minute: reminderMinute
      )) ?? Date()
    } set: { date in
      let components = Calendar.current.dateComponents([.hour, .minute], from: date)
      reminderHour = components.hour ?? 9
      reminderMinute = components.minute ?? 0
    }
  }

  @MainActor
  private func saveReminderPreference() async {
    if dailyReminderEnabled {
      do {
        let granted = try await reminderService.requestAuthorization()
        guard granted else {
          dailyReminderEnabled = false
          statusMessage = "Notification permission was not granted."
          return
        }
        try await reminderService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute, dueCount: 0)
        statusMessage = "Daily reminder scheduled."
      } catch {
        dailyReminderEnabled = false
        statusMessage = "Could not schedule reminder: \(error)"
      }
    } else {
      reminderService.cancelDailyReminder()
      statusMessage = "Daily reminder disabled."
    }
  }
}

private struct ShortcutRecorderView: NSViewRepresentable {
  @Binding var isRecording: Bool
  let onCapture: (VocraCore.KeyboardShortcut) -> Void

  func makeNSView(context: Context) -> RecorderView {
    let view = RecorderView()
    view.onCapture = onCapture
    view.onCancel = { isRecording = false }
    return view
  }

  func updateNSView(_ nsView: RecorderView, context: Context) {
    nsView.isRecording = isRecording
    nsView.onCapture = onCapture
    nsView.onCancel = { isRecording = false }
    if isRecording {
      DispatchQueue.main.async {
        nsView.window?.makeFirstResponder(nsView)
      }
    }
  }

  final class RecorderView: NSView {
    var isRecording = false
    var onCapture: ((VocraCore.KeyboardShortcut) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool {
      true
    }

    override func keyDown(with event: NSEvent) {
      guard isRecording else {
        super.keyDown(with: event)
        return
      }

      if Int(event.keyCode) == kVK_Escape {
        onCancel?()
        return
      }

      guard let shortcut = VocraCore.KeyboardShortcut(event: event) else {
        NSSound.beep()
        return
      }

      onCapture?(shortcut)
    }
  }
}

private extension VocraCore.KeyboardShortcut {
  init?(event: NSEvent) {
    let modifiers = Self.carbonModifiers(from: event.modifierFlags)
    let shortcut = VocraCore.KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    guard shortcut.isValid else { return nil }
    self = shortcut
  }

  static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var modifiers: UInt32 = 0
    if flags.contains(.command) {
      modifiers |= UInt32(cmdKey)
    }
    if flags.contains(.option) {
      modifiers |= UInt32(optionKey)
    }
    if flags.contains(.control) {
      modifiers |= UInt32(controlKey)
    }
    if flags.contains(.shift) {
      modifiers |= UInt32(shiftKey)
    }
    return modifiers
  }
}
