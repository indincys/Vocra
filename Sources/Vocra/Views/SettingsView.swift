import SwiftUI
import VocraCore

struct SettingsView: View {
  private let settingsStore = UserDefaultsSettingsStore()
  private let apiKeyStore = KeychainAPIKeyStore()
  private let promptStore = UserDefaultsPromptStore()
  private let reminderService = ReviewReminderService()

  @State private var baseURL = APIConfiguration.default.baseURL.absoluteString
  @State private var model = APIConfiguration.default.model
  @State private var temperature = APIConfiguration.default.temperature
  @State private var timeout = APIConfiguration.default.timeoutSeconds
  @State private var apiKey = ""
  @State private var wordPrompt = ""
  @State private var phrasePrompt = ""
  @State private var sentencePrompt = ""
  @State private var cardPrompt = ""
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
        SliderRow(title: "Temperature", value: $temperature, range: 0...2)
        Stepper("Timeout: \(Int(timeout)) seconds", value: $timeout, in: 5...120, step: 5)
        Button("Save API Settings", action: saveAPISettings)
      }

      Section("Prompts") {
        promptEditor("Word Explanation", text: $wordPrompt)
        promptEditor("Term Explanation", text: $phrasePrompt)
        promptEditor("Sentence Explanation", text: $sentencePrompt)
        promptEditor("Vocabulary Card", text: $cardPrompt)
        Button("Save Prompts", action: savePrompts)
      }

      Section("Review") {
        Toggle("Daily Reminder", isOn: $dailyReminderEnabled)
        Stepper("Hour: \(reminderHour)", value: $reminderHour, in: 0...23)
        Stepper("Minute: \(reminderMinute)", value: $reminderMinute, in: 0...59, step: 5)
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
    temperature = configuration.temperature
    timeout = configuration.timeoutSeconds
    apiKey = (try? apiKeyStore.readAPIKey()) ?? ""
    wordPrompt = promptStore.template(for: .wordExplanation)?.body ?? ""
    phrasePrompt = promptStore.template(for: .phraseExplanation)?.body ?? ""
    sentencePrompt = promptStore.template(for: .sentenceExplanation)?.body ?? ""
    cardPrompt = promptStore.template(for: .vocabularyCard)?.body ?? ""
  }

  private func saveAPISettings() {
    guard let url = URL(string: baseURL) else {
      statusMessage = "Base URL is invalid."
      return
    }

    settingsStore.saveAPIConfiguration(APIConfiguration(
      baseURL: url,
      model: model,
      temperature: temperature,
      timeoutSeconds: timeout
    ))

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

  private func savePrompts() {
    promptStore.save(PromptTemplate(kind: .wordExplanation, body: wordPrompt))
    promptStore.save(PromptTemplate(kind: .phraseExplanation, body: phrasePrompt))
    promptStore.save(PromptTemplate(kind: .sentenceExplanation, body: sentencePrompt))
    promptStore.save(PromptTemplate(kind: .vocabularyCard, body: cardPrompt))
    statusMessage = "Prompts saved."
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

private struct SliderRow: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>

  var body: some View {
    HStack {
      Text(title)
      Slider(value: $value, in: range, step: 0.1)
      Text(value.formatted(.number.precision(.fractionLength(1))))
        .monospacedDigit()
        .frame(width: 36, alignment: .trailing)
    }
  }
}
