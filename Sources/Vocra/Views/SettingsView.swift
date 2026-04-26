import AppKit
import Carbon
import SwiftUI
import VocraCore

enum APIConnectionTestStatus: Equatable {
  case idle
  case testing
  case succeeded
  case failed

  var systemImageName: String? {
    switch self {
    case .idle:
      nil
    case .testing:
      "arrow.triangle.2.circlepath"
    case .succeeded:
      "checkmark.circle.fill"
    case .failed:
      "xmark.octagon.fill"
    }
  }

  var tint: Color {
    switch self {
    case .idle, .testing:
      .secondary
    case .succeeded:
      .green
    case .failed:
      .red
    }
  }
}

private struct APIProfileForm: Identifiable, Equatable {
  var id: UUID
  var name: String
  var baseURL: String
  var model: String
  var timeout: Double
  var apiKey: String

  init(profile: APIProviderProfile, apiKey: String) {
    self.id = profile.id
    self.name = profile.name
    self.baseURL = profile.configuration.baseURL.absoluteString
    self.model = profile.configuration.model
    self.timeout = profile.configuration.timeoutSeconds
    self.apiKey = apiKey
  }

  init(id: UUID = UUID(), name: String, configuration: APIConfiguration = .default, apiKey: String = "") {
    self.id = id
    self.name = name
    self.baseURL = configuration.baseURL.absoluteString
    self.model = configuration.model
    self.timeout = configuration.timeoutSeconds
    self.apiKey = apiKey
  }

  var displayName: String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Unnamed Provider" : trimmed
  }

  func profile() -> APIProviderProfile? {
    guard let url = URL(string: baseURL) else { return nil }
    return APIProviderProfile(
      id: id,
      name: displayName,
      configuration: APIConfiguration(baseURL: url, model: model, timeoutSeconds: timeout)
    )
  }
}

struct SettingsView: View {
  private let settingsStore = UserDefaultsSettingsStore()
  private let promptStore = UserDefaultsPromptStore()
  private let reminderService = ReviewReminderService()

  @State private var apiProfiles: [APIProfileForm] = []
  @State private var activeProfileID = APIProviderProfile.defaultProfileID
  @State private var expandedProfileIDs: Set<UUID> = []
  @State private var testStatusByProfileID: [UUID: APIConnectionTestStatus] = [:]
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
      apiSection

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

  private var apiSection: some View {
    Section("API") {
      Picker("Current Provider", selection: $activeProfileID) {
        ForEach(apiProfiles) { profile in
          Text(profile.displayName).tag(profile.id)
        }
      }
      .onChange(of: activeProfileID) { _, newValue in
        expandedProfileIDs.insert(newValue)
        saveAPISettings()
      }

      ForEach($apiProfiles) { $profile in
        DisclosureGroup(isExpanded: expansionBinding(for: profile.id)) {
          TextField("Provider Name", text: $profile.name)
          TextField("Base URL", text: $profile.baseURL)
          TextField("Model", text: $profile.model)
          SecureField("API Key", text: $profile.apiKey)
          Stepper("Timeout: \(Int(profile.timeout)) seconds", value: $profile.timeout, in: 5...120, step: 5)

          HStack {
            Button(profile.id == activeProfileID ? "Selected" : "Use This Provider") {
              activeProfileID = profile.id
              saveAPISettings()
            }
            .disabled(profile.id == activeProfileID)

            Button("Delete Provider") {
              deleteAPIProfile(profile.id)
            }
            .disabled(apiProfiles.count <= 1)

            Spacer()

            connectionStatusIcon(for: profile.id)
          }
        } label: {
          HStack {
            Text(profile.displayName)
            if profile.id == activeProfileID {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            }
          }
        }
      }

      HStack {
        Button("Add Provider", action: addAPIProfile)
        Button("Save API Settings", action: saveAPISettings)
        Button {
          Task {
            await testAPIConnection()
          }
        } label: {
          Label(isTestingAPI ? "Testing API..." : "测试API", systemImage: "network")
        }
        .disabled(isTestingAPI || activeProfileForm == nil)

        connectionStatusIcon(for: activeProfileID)
      }
    }
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
    let providerSettings = settingsStore.loadAPIProviderSettings()
    apiProfiles = providerSettings.profiles.map { profile in
      APIProfileForm(profile: profile, apiKey: (try? apiKeyStore(for: profile.id).readAPIKey()) ?? "")
    }
    activeProfileID = providerSettings.activeProfileID
    expandedProfileIDs = [providerSettings.activeProfileID]
    testStatusByProfileID = [:]
    wordPrompt = promptStore.template(for: .wordExplanation)?.body ?? ""
    phrasePrompt = promptStore.template(for: .phraseExplanation)?.body ?? ""
    sentencePrompt = promptStore.template(for: .sentenceExplanation)?.body ?? ""
    cardPrompt = promptStore.template(for: .vocabularyCard)?.body ?? ""
    keyboardShortcut = settingsStore.loadKeyboardShortcut()
  }

  private func saveAPISettings() {
    guard !apiProfiles.isEmpty else {
      statusMessage = "At least one API provider is required."
      return
    }

    var profiles: [APIProviderProfile] = []
    for profileForm in apiProfiles {
      guard let profile = profileForm.profile() else {
        statusMessage = "Base URL is invalid for \(profileForm.displayName)."
        return
      }
      profiles.append(profile)
    }

    if !profiles.contains(where: { $0.id == activeProfileID }) {
      activeProfileID = profiles[0].id
    }

    settingsStore.saveAPIProviderSettings(APIProviderSettings(
      profiles: profiles,
      activeProfileID: activeProfileID
    ))

    do {
      for profile in apiProfiles {
        let keyStore = apiKeyStore(for: profile.id)
        if profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          try keyStore.deleteAPIKey()
        } else {
          try keyStore.saveAPIKey(profile.apiKey)
        }
      }
      statusMessage = "API settings saved."
    } catch {
      statusMessage = "API key save failed: \(error)"
    }
  }

  @MainActor
  private func testAPIConnection() async {
    guard let profile = activeProfileForm, let configuration = currentAPIConfiguration() else {
      statusMessage = "Base URL is invalid."
      return
    }

    isTestingAPI = true
    testStatusByProfileID[profile.id] = .testing
    statusMessage = "Testing API connection..."
    defer { isTestingAPI = false }

    do {
      try await APIConnectionTester().test(configuration: configuration, apiKey: profile.apiKey)
      testStatusByProfileID[profile.id] = .succeeded
      statusMessage = "API connection succeeded."
    } catch {
      testStatusByProfileID[profile.id] = .failed
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
    guard let profile = activeProfileForm, let url = URL(string: profile.baseURL) else { return nil }
    return APIConfiguration(
      baseURL: url,
      model: profile.model,
      timeoutSeconds: profile.timeout
    )
  }

  private var activeProfileForm: APIProfileForm? {
    apiProfiles.first { $0.id == activeProfileID }
  }

  private func addAPIProfile() {
    let profile = APIProfileForm(name: "New Provider")
    apiProfiles.append(profile)
    activeProfileID = profile.id
    expandedProfileIDs.insert(profile.id)
    testStatusByProfileID[profile.id] = .idle
  }

  private func deleteAPIProfile(_ id: UUID) {
    guard apiProfiles.count > 1 else { return }
    apiProfiles.removeAll { $0.id == id }
    expandedProfileIDs.remove(id)
    testStatusByProfileID.removeValue(forKey: id)
    try? apiKeyStore(for: id).deleteAPIKey()
    if activeProfileID == id {
      activeProfileID = apiProfiles[0].id
    }
    saveAPISettings()
  }

  private func expansionBinding(for id: UUID) -> Binding<Bool> {
    Binding {
      expandedProfileIDs.contains(id)
    } set: { isExpanded in
      if isExpanded {
        expandedProfileIDs.insert(id)
      } else {
        expandedProfileIDs.remove(id)
      }
    }
  }

  @ViewBuilder
  private func connectionStatusIcon(for id: UUID) -> some View {
    let status = testStatusByProfileID[id] ?? .idle
    if let systemImageName = status.systemImageName {
      Image(systemName: systemImageName)
        .foregroundStyle(status.tint)
        .symbolEffect(.pulse, isActive: status == .testing)
        .accessibilityLabel(statusAccessibilityLabel(status))
    }
  }

  private func statusAccessibilityLabel(_ status: APIConnectionTestStatus) -> String {
    switch status {
    case .idle:
      "Not tested"
    case .testing:
      "Testing API connection"
    case .succeeded:
      "API connection succeeded"
    case .failed:
      "API connection failed"
    }
  }

  private func apiKeyStore(for profileID: UUID) -> KeychainAPIKeyStore {
    let account = profileID == APIProviderProfile.defaultProfileID
      ? KeychainAPIKeyStore.legacyAccount
      : "\(KeychainAPIKeyStore.legacyAccount).\(profileID.uuidString)"
    return KeychainAPIKeyStore(account: account)
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
