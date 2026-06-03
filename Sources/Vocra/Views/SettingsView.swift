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
    return trimmed.isEmpty ? "未命名服务商" : trimmed
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

struct SettingsSchemaPromptEditor: Equatable {
  let title: String
  let kind: PromptKind
}

enum SettingsSchemaPromptEditors {
  static let sentence = SettingsSchemaPromptEditor(
    title: "Sentence Analysis Schema",
    kind: .sentenceAnalysisSchema
  )
  static let word = SettingsSchemaPromptEditor(
    title: "Word and Term Explanation Schema",
    kind: .wordExplanationSchema
  )
  static let card = SettingsSchemaPromptEditor(
    title: "Vocabulary Card Schema",
    kind: .vocabularyCardSchema
  )

  static let all = [sentence, word, card]
}

private let apiPresets: [(name: String, baseURL: String, model: String)] = [
  ("Claude", "https://api.anthropic.com/v1", "claude-sonnet-4-5"),
  ("OpenAI", "https://api.openai.com/v1", "gpt-4o"),
  ("DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
]

struct SettingsView: View {
  private let settingsStore = UserDefaultsSettingsStore()
  private let promptStore = UserDefaultsPromptStore()
  private let reminderService = ReviewReminderService()

  @State private var apiProfiles: [APIProfileForm] = []
  @State private var activeProfileID = APIProviderProfile.defaultProfileID
  @State private var testStatusByProfileID: [UUID: APIConnectionTestStatus] = [:]
  @State private var isTestingAPI = false
  @State private var showKey = false
  @State private var wordPrompt = ""
  @State private var sentencePrompt = ""
  @State private var cardPrompt = ""
  @State private var showSchemaPrompts = false
  @State private var explanationDepth = LearningPreferences.ExplanationDepth.detailed
  @State private var exampleCount = 2
  @State private var chineseStyle = LearningPreferences.ChineseStyle.teacherLike
  @State private var diagramDensity = LearningPreferences.DiagramDensity.full
  @State private var keyboardShortcut = VocraCore.KeyboardShortcut.defaultShortcut
  @State private var isRecordingShortcut = false
  @State private var statusMessage = ""
  @AppStorage("vocra.voiceAccent") private var voiceAccent = "us"
  @AppStorage("vocra.autoSpeak") private var autoSpeak = true
  @AppStorage("vocra.dailyReminderEnabled") private var dailyReminderEnabled = false
  @AppStorage("vocra.reminderHour") private var reminderHour = 9
  @AppStorage("vocra.reminderMinute") private var reminderMinute = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("设置")
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)

        shortcutSection
        apiSection
        speechSection
        learningSection
        schemaSection
        reminderSection

        if !statusMessage.isEmpty {
          HStack(spacing: 7) {
            Image(systemName: "info.circle")
            Text(statusMessage)
          }
          .font(.system(size: 12.5))
          .foregroundStyle(VocraTheme.ink500)
        }
      }
      .padding(.horizontal, 34)
      .padding(.vertical, 30)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollContentBackground(.hidden)
    .overlay {
      ShortcutRecorderView(isRecording: $isRecordingShortcut) { shortcut in
        keyboardShortcut = shortcut
        isRecordingShortcut = false
        saveKeyboardShortcut()
      }
      .frame(width: 1, height: 1)
      .accessibilityHidden(true)
      .allowsHitTesting(false)
    }
    .onAppear(perform: load)
  }

  // MARK: Sections

  private var shortcutSection: some View {
    sectionCard("command", "全局快捷键") {
      row("划词查询 / 解析", "在任意 App 中选中文本后触发") {
        keyCapRow(keyboardShortcut.displayString)
      }
      rowDivider
      row("录制快捷键", isRecordingShortcut ? "请按下新的组合键，Esc 取消" : nil) {
        HStack(spacing: 8) {
          Button(isRecordingShortcut ? "录制中…" : "录制") { isRecordingShortcut.toggle() }
            .buttonStyle(VocraGhostButtonStyle())
          Button("恢复默认") {
            keyboardShortcut = .defaultShortcut
            saveKeyboardShortcut()
          }
          .buttonStyle(VocraGhostButtonStyle())
        }
      }
    }
  }

  private var apiSection: some View {
    sectionCard("sparkles", "模型 API") {
      field("服务商", "选预设快速填入，或自定义兼容端点") {
        VStack(alignment: .leading, spacing: 8) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(apiProfiles) { profile in
                Button {
                  activeProfileID = profile.id
                  saveAPISettings()
                } label: {
                  Text(profile.displayName).lineLimit(1)
                }
                .buttonStyle(ProviderPillStyle(selected: profile.id == activeProfileID))
                .overlay(alignment: .topTrailing) { connectionStatusIcon(for: profile.id).font(.system(size: 10)).offset(x: 4, y: -4) }
              }
              Button { addAPIProfile() } label: { Image(systemName: "plus") }
                .buttonStyle(VocraGhostButtonStyle())
            }
            .padding(.vertical, 2)
          }
          HStack(spacing: 7) {
            Text("预设").font(.system(size: 11.5)).foregroundStyle(VocraTheme.ink400)
            ForEach(apiPresets, id: \.name) { preset in
              Button(preset.name) { applyPreset(preset) }
                .buttonStyle(VocraGhostButtonStyle(tint: VocraTheme.accentInk))
            }
          }
        }
      }
      if let index = activeIndex {
        rowDivider
        field("Base URL", "兼容 OpenAI / Anthropic 协议的接口地址") {
          textInput("https://your-endpoint/v1", text: $apiProfiles[index].baseURL, mono: true)
        }
        rowDivider
        field("API Key", "仅保存在本地钥匙串，不会上传") {
          ZStack(alignment: .trailing) {
            Group {
              if showKey {
                textInput("sk-...", text: $apiProfiles[index].apiKey, mono: true)
              } else {
                secureInput("sk-...", text: $apiProfiles[index].apiKey)
              }
            }
            Button(showKey ? "隐藏" : "显示") { showKey.toggle() }
              .buttonStyle(VocraGhostButtonStyle())
              .padding(.trailing, 5)
          }
        }
        rowDivider
        field("Model ID", "用于查词与句子解析的模型名") {
          textInput("claude-sonnet-4-5 / gpt-4o / ...", text: $apiProfiles[index].model, mono: true)
        }
        rowDivider
        field("服务商名称") {
          textInput("自定义名称", text: $apiProfiles[index].name)
        }
        rowDivider
        row("请求超时", "\(Int(apiProfiles[index].timeout)) 秒") {
          Stepper("", value: $apiProfiles[index].timeout, in: 5...120, step: 5).labelsHidden()
        }
      }
      rowDivider
      HStack(spacing: 8) {
        Button("保存") { saveAPISettings() }.buttonStyle(VocraAccentButtonStyle(horizontalPadding: 16, verticalPadding: 7))
        Button { Task { await testAPIConnection() } } label: {
          Label(isTestingAPI ? "测试中…" : "测试连接", systemImage: "network")
        }
        .buttonStyle(VocraGhostButtonStyle())
        .disabled(isTestingAPI || activeIndex == nil)
        Spacer()
        Button("删除当前") { deleteAPIProfile(activeProfileID) }
          .buttonStyle(VocraGhostButtonStyle(tint: VocraTheme.rolePredicateInk))
          .disabled(apiProfiles.count <= 1)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  private var speechSection: some View {
    sectionCard("speaker.wave.2", "朗读") {
      row("发音口音", "单词与例句的朗读音色") {
        VocraSegmented(
          options: [("us", "美音"), ("uk", "英音")],
          selection: $voiceAccent
        )
        .frame(width: 130)
      }
      rowDivider
      row("查词后自动朗读", "弹出释义时自动读出单词") {
        Toggle("", isOn: $autoSpeak).toggleStyle(.switch).labelsHidden().tint(VocraTheme.accent)
      }
    }
  }

  private var learningSection: some View {
    sectionCard("book", "释义偏好") {
      row("讲解深度") {
        VocraSegmented(
          options: [(.standard, "标准"), (.detailed, "详细")],
          selection: $explanationDepth, onChange: { _ in saveLearningSettings() }
        ).frame(width: 130)
      }
      rowDivider
      row("例句数量") {
        VocraSegmented(
          options: [(1, "1"), (2, "2"), (3, "3")],
          selection: $exampleCount, onChange: { _ in saveLearningSettings() }
        ).frame(width: 130)
      }
      rowDivider
      row("中文风格") {
        VocraSegmented(
          options: [(.concise, "简洁"), (.teacherLike, "讲解式")],
          selection: $chineseStyle, onChange: { _ in saveLearningSettings() }
        ).frame(width: 150)
      }
      rowDivider
      row("图示密度") {
        VocraSegmented(
          options: [(.simple, "精简"), (.full, "完整")],
          selection: $diagramDensity, onChange: { _ in saveLearningSettings() }
        ).frame(width: 130)
      }
    }
  }

  private var schemaSection: some View {
    sectionCard("curlybraces", "结构化输出 · Schema") {
      row("强制 JSON Schema", "按固定字段返回，显著提升稳定性") {
        Button(showSchemaPrompts ? "收起" : "编辑提示词") { showSchemaPrompts.toggle() }
          .buttonStyle(VocraGhostButtonStyle())
      }
      if showSchemaPrompts {
        rowDivider
        VStack(alignment: .leading, spacing: 14) {
          promptEditor(SettingsSchemaPromptEditors.sentence.title, "句子解析", text: $sentencePrompt)
          promptEditor(SettingsSchemaPromptEditors.word.title, "单词 / 词组", text: $wordPrompt)
          promptEditor(SettingsSchemaPromptEditors.card.title, "单词卡", text: $cardPrompt)
          Button("保存 Schema 提示词") { savePrompts() }
            .buttonStyle(VocraAccentButtonStyle(horizontalPadding: 16, verticalPadding: 7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
    }
  }

  private var reminderSection: some View {
    sectionCard("bell", "复习提醒") {
      row("每日提醒", "在固定时间提醒你回来复习") {
        Toggle("", isOn: $dailyReminderEnabled).toggleStyle(.switch).labelsHidden().tint(VocraTheme.accent)
      }
      rowDivider
      row("提醒时间") {
        DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
          .labelsHidden()
      }
      rowDivider
      HStack {
        Button(dailyReminderEnabled ? "保存提醒" : "关闭提醒") {
          Task { await saveReminderPreference() }
        }
        .buttonStyle(VocraGhostButtonStyle())
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  // MARK: Styled atoms

  private func sectionCard<Content: View>(_ icon: String, _ title: String, @ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      VocraSectionLabel(systemImage: icon, title: title)
      VStack(spacing: 0) { content() }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vocraCard(cornerRadius: 14, padding: nil)
    }
  }

  private var rowDivider: some View { VocraTheme.hairline.frame(height: 1) }

  private func row<Control: View>(_ label: String, _ desc: String? = nil, @ViewBuilder control: () -> Control) -> some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
        Text(label).font(.system(size: 14.5)).foregroundStyle(VocraTheme.ink900)
        if let desc, !desc.isEmpty {
          Text(desc).font(.system(size: 12)).foregroundStyle(VocraTheme.ink400)
        }
      }
      Spacer(minLength: 12)
      control()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
  }

  private func field<Control: View>(_ label: String, _ desc: String? = nil, @ViewBuilder control: () -> Control) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(label).font(.system(size: 14.5)).foregroundStyle(VocraTheme.ink900)
        if let desc { Text(desc).font(.system(size: 12)).foregroundStyle(VocraTheme.ink400) }
      }
      control()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func keyCapRow(_ display: String) -> some View {
    // Split leading modifier glyphs (⌃⌥⇧⌘) into individual caps and keep the
    // remaining key name (e.g. "Space", "D") as one cap.
    let modifierGlyphs: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]
    var caps: [String] = []
    var key = ""
    for character in display {
      if key.isEmpty, modifierGlyphs.contains(character) {
        caps.append(String(character))
      } else {
        key.append(character)
      }
    }
    if !key.isEmpty { caps.append(key) }
    return HStack(spacing: 5) {
      ForEach(Array(caps.enumerated()), id: \.offset) { _, cap in
        KbdKey(cap, large: true)
      }
    }
  }

  private func textInput(_ placeholder: String, text: Binding<String>, mono: Bool = false) -> some View {
    TextField(placeholder, text: text)
      .textFieldStyle(.plain)
      .font(.system(size: 13, design: mono ? .monospaced : .default))
      .foregroundStyle(VocraTheme.ink900)
      .padding(.horizontal, 11)
      .padding(.vertical, 9)
      .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      .overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(VocraTheme.hairline, lineWidth: 1) }
  }

  private func secureInput(_ placeholder: String, text: Binding<String>) -> some View {
    SecureField(placeholder, text: text)
      .textFieldStyle(.plain)
      .font(.system(size: 13, design: .monospaced))
      .foregroundStyle(VocraTheme.ink900)
      .padding(.horizontal, 11)
      .padding(.vertical, 9)
      .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      .overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(VocraTheme.hairline, lineWidth: 1) }
  }

  private func promptEditor(_ title: String, _ subtitle: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 7) {
        Text(subtitle).font(.system(size: 13, weight: .semibold)).foregroundStyle(VocraTheme.ink900)
        Text(title).font(.system(size: 11)).foregroundStyle(VocraTheme.ink400)
      }
      TextEditor(text: text)
        .font(.system(size: 12, design: .monospaced))
        .scrollContentBackground(.hidden)
        .frame(minHeight: 100)
        .padding(8)
        .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(VocraTheme.hairline, lineWidth: 1) }
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

  // MARK: State + actions

  private var activeIndex: Int? {
    apiProfiles.firstIndex { $0.id == activeProfileID }
  }

  private var activeProfileForm: APIProfileForm? {
    apiProfiles.first { $0.id == activeProfileID }
  }

  private func applyPreset(_ preset: (name: String, baseURL: String, model: String)) {
    guard let index = activeIndex else { return }
    apiProfiles[index].baseURL = preset.baseURL
    apiProfiles[index].model = preset.model
    if apiProfiles[index].name.trimmingCharacters(in: .whitespaces).isEmpty || apiProfiles[index].name == "未命名服务商" {
      apiProfiles[index].name = preset.name
    }
  }

  private func load() {
    let providerSettings = settingsStore.loadAPIProviderSettings()
    apiProfiles = providerSettings.profiles.map { profile in
      APIProfileForm(profile: profile, apiKey: (try? apiKeyStore(for: profile.id).readAPIKey()) ?? "")
    }
    activeProfileID = providerSettings.activeProfileID
    testStatusByProfileID = [:]
    let learningPreferences = settingsStore.loadLearningPreferences()
    explanationDepth = learningPreferences.explanationDepth
    exampleCount = learningPreferences.exampleCount
    chineseStyle = learningPreferences.chineseStyle
    diagramDensity = learningPreferences.diagramDensity
    wordPrompt = promptStore.template(for: SettingsSchemaPromptEditors.word.kind)?.body ?? ""
    sentencePrompt = promptStore.template(for: SettingsSchemaPromptEditors.sentence.kind)?.body ?? ""
    cardPrompt = promptStore.template(for: SettingsSchemaPromptEditors.card.kind)?.body ?? ""
    keyboardShortcut = settingsStore.loadKeyboardShortcut()
  }

  private func saveAPISettings() {
    guard !apiProfiles.isEmpty else {
      statusMessage = "至少需要一个 API 服务商。"
      return
    }

    var profiles: [APIProviderProfile] = []
    for profileForm in apiProfiles {
      guard let profile = profileForm.profile() else {
        statusMessage = "「\(profileForm.displayName)」的 Base URL 无效。"
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
      statusMessage = "API 设置已保存。"
    } catch {
      statusMessage = "API 密钥保存失败：\(error)"
    }
  }

  @MainActor
  private func testAPIConnection() async {
    guard let profile = activeProfileForm, let configuration = currentAPIConfiguration() else {
      statusMessage = "Base URL 无效。"
      return
    }

    isTestingAPI = true
    testStatusByProfileID[profile.id] = .testing
    statusMessage = "正在测试 API 连接…"
    defer { isTestingAPI = false }

    do {
      try await APIConnectionTester().test(configuration: configuration, apiKey: profile.apiKey)
      testStatusByProfileID[profile.id] = .succeeded
      statusMessage = "API 连接成功。"
    } catch {
      testStatusByProfileID[profile.id] = .failed
      statusMessage = "API 连接失败：\(error)"
    }
  }

  private func savePrompts() {
    promptStore.save(PromptTemplate(kind: SettingsSchemaPromptEditors.sentence.kind, body: sentencePrompt))
    promptStore.save(PromptTemplate(kind: SettingsSchemaPromptEditors.word.kind, body: wordPrompt))
    promptStore.save(PromptTemplate(kind: SettingsSchemaPromptEditors.card.kind, body: cardPrompt))
    statusMessage = "Schema 提示词已保存。"
  }

  private func saveLearningSettings() {
    settingsStore.saveLearningPreferences(LearningPreferences(
      explanationDepth: explanationDepth,
      exampleCount: exampleCount,
      chineseStyle: chineseStyle,
      diagramDensity: diagramDensity
    ))
    statusMessage = "释义偏好已保存。"
  }

  private func saveKeyboardShortcut() {
    settingsStore.saveKeyboardShortcut(keyboardShortcut)
    NotificationCenter.default.post(
      name: .vocraKeyboardShortcutDidChange,
      object: nil,
      userInfo: [VocraNotificationUserInfoKey.keyboardShortcut: keyboardShortcut]
    )
    statusMessage = "快捷键已保存：\(keyboardShortcut.displayString)。"
  }

  private func currentAPIConfiguration() -> APIConfiguration? {
    guard let profile = activeProfileForm, let url = URL(string: profile.baseURL) else { return nil }
    return APIConfiguration(
      baseURL: url,
      model: profile.model,
      timeoutSeconds: profile.timeout
    )
  }

  private func addAPIProfile() {
    let profile = APIProfileForm(name: "新服务商")
    apiProfiles.append(profile)
    activeProfileID = profile.id
    testStatusByProfileID[profile.id] = .idle
  }

  private func deleteAPIProfile(_ id: UUID) {
    guard apiProfiles.count > 1 else { return }
    apiProfiles.removeAll { $0.id == id }
    testStatusByProfileID.removeValue(forKey: id)
    try? apiKeyStore(for: id).deleteAPIKey()
    if activeProfileID == id {
      activeProfileID = apiProfiles[0].id
    }
    saveAPISettings()
  }

  private func statusAccessibilityLabel(_ status: APIConnectionTestStatus) -> String {
    switch status {
    case .idle:
      "未测试"
    case .testing:
      "正在测试 API 连接"
    case .succeeded:
      "API 连接成功"
    case .failed:
      "API 连接失败"
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
          statusMessage = "通知权限未被授予。"
          return
        }
        try await reminderService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute, dueCount: 0)
        statusMessage = "每日提醒已设置。"
      } catch {
        dailyReminderEnabled = false
        statusMessage = "无法设置提醒：\(error)"
      }
    } else {
      reminderService.cancelDailyReminder()
      statusMessage = "每日提醒已关闭。"
    }
  }
}

private struct ProviderPillStyle: ButtonStyle {
  let selected: Bool
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(selected ? Color.white : VocraTheme.ink700)
      .padding(.horizontal, 13)
      .padding(.vertical, 6)
      .background {
        if selected {
          Capsule().fill(VocraTheme.accent).shadow(color: VocraTheme.accent.opacity(0.4), radius: 4, y: 2)
        } else {
          Capsule().fill(VocraTheme.fill)
        }
      }
      .opacity(configuration.isPressed ? 0.7 : 1)
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
