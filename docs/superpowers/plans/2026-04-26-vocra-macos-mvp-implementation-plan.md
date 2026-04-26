# Vocra macOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first native macOS 26+ Vocra MVP: one global shortcut reads selected English text, classifies it, calls an OpenAI-compatible API, shows a Liquid Glass floating panel, and saves words/phrases for review.

**Architecture:** Use a SwiftPM macOS GUI app with a `VocraCore` library target and a thin `Vocra` executable target. Keep pure logic in `VocraCore` for unit testing; keep app lifecycle, menu bar scenes, floating `NSPanel`, and permission-driven platform services behind small interfaces.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Security Keychain, Carbon hotkeys, AXUIElement Accessibility APIs, SQLite3, URLSession, UserNotifications, XCTest, project-local `.app` run script.

---

## Scope Check

The approved spec has several subsystems, but they serve one integrated MVP flow. This plan keeps them in one implementation sequence because each task unlocks a working slice of the app. Stop after any task only if that task builds and its tests pass.

## File Structure

Create this structure:

```text
Package.swift
.codex/environments/environment.toml
script/build_and_run.sh
Sources/Vocra/App/VocraApp.swift
Sources/Vocra/App/AppDelegate.swift
Sources/Vocra/App/AppModel.swift
Sources/Vocra/Views/RootView.swift
Sources/Vocra/Views/SettingsView.swift
Sources/Vocra/Views/VocabularyListView.swift
Sources/Vocra/Views/ReviewView.swift
Sources/Vocra/Views/ExplanationPanelView.swift
Sources/Vocra/Support/FloatingPanelController.swift
Sources/VocraCore/Models/APIConfiguration.swift
Sources/VocraCore/Models/CapturedText.swift
Sources/VocraCore/Models/ExplanationMode.swift
Sources/VocraCore/Models/PromptTemplate.swift
Sources/VocraCore/Models/VocabularyCard.swift
Sources/VocraCore/Services/AIClient.swift
Sources/VocraCore/Services/OpenAICompatibleClient.swift
Sources/VocraCore/Services/PromptRenderer.swift
Sources/VocraCore/Services/ReviewScheduler.swift
Sources/VocraCore/Services/ReviewReminderService.swift
Sources/VocraCore/Services/SelectionReader.swift
Sources/VocraCore/Services/ShortcutService.swift
Sources/VocraCore/Services/TextClassifier.swift
Sources/VocraCore/Stores/APIKeyStore.swift
Sources/VocraCore/Stores/PromptStore.swift
Sources/VocraCore/Stores/SettingsStore.swift
Sources/VocraCore/Stores/VocabularyRepository.swift
Sources/VocraCore/Support/SQLiteDatabase.swift
Tests/VocraCoreTests/AIClientTests.swift
Tests/VocraCoreTests/PromptStoreTests.swift
Tests/VocraCoreTests/PromptRendererTests.swift
Tests/VocraCoreTests/ReviewSchedulerTests.swift
Tests/VocraCoreTests/ScaffoldTests.swift
Tests/VocraCoreTests/TextClassifierTests.swift
Tests/VocraCoreTests/VocabularyRepositoryTests.swift
```

Responsibility boundaries:

- `Vocra` executable target: SwiftUI scenes, menu bar, AppKit panel bridge, app coordination.
- `VocraCore` target: models, API client, prompt rendering, text classification, selection reading interfaces, shortcut interfaces, settings, Keychain, SQLite repository.
- `Tests/VocraCoreTests`: all pure logic and persistence tests. UI and permission-heavy services get build verification plus manual checks.

## Task 1: SwiftPM App Scaffold And Run Harness

**Files:**
- Create: `Package.swift`
- Create: `Sources/Vocra/App/VocraApp.swift`
- Create: `Sources/Vocra/App/AppDelegate.swift`
- Create: `Sources/Vocra/Views/RootView.swift`
- Create: `Sources/VocraCore/Models/ExplanationMode.swift`
- Create: `Tests/VocraCoreTests/ScaffoldTests.swift`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

- [ ] **Step 1: Create the package manifest**

Write `Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Vocra",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "Vocra", targets: ["Vocra"])
  ],
  targets: [
    .target(
      name: "VocraCore",
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    ),
    .executableTarget(
      name: "Vocra",
      dependencies: ["VocraCore"]
    ),
    .testTarget(
      name: "VocraCoreTests",
      dependencies: ["VocraCore"]
    )
  ]
)
```

- [ ] **Step 2: Add the first model**

Write `Sources/VocraCore/Models/ExplanationMode.swift`:

```swift
import Foundation

public enum ExplanationMode: String, CaseIterable, Codable, Equatable, Sendable {
  case word
  case phrase
  case sentence

  public var displayName: String {
    switch self {
    case .word: "Word"
    case .phrase: "Term"
    case .sentence: "Sentence"
    }
  }
}
```

- [ ] **Step 3: Add a scaffold test**

Write `Tests/VocraCoreTests/ScaffoldTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class ScaffoldTests: XCTestCase {
  func testExplanationModeDisplayNames() {
    XCTAssertEqual(ExplanationMode.word.displayName, "Word")
    XCTAssertEqual(ExplanationMode.phrase.displayName, "Term")
    XCTAssertEqual(ExplanationMode.sentence.displayName, "Sentence")
  }
}
```

- [ ] **Step 4: Run the first test**

Run: `swift test --filter ScaffoldTests`

Expected: PASS.

- [ ] **Step 5: Add the app delegate**

Write `Sources/Vocra/App/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
```

- [ ] **Step 6: Add the root SwiftUI view**

Write `Sources/Vocra/Views/RootView.swift`:

```swift
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
```

- [ ] **Step 7: Add the SwiftUI app entrypoint**

Write `Sources/Vocra/App/VocraApp.swift`:

```swift
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
```

- [ ] **Step 8: Add the build and run script**

Write `script/build_and_run.sh` and make it executable:

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Vocra"
BUNDLE_ID="com.indincys.Vocra"
MIN_SYSTEM_VERSION="26.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

Run: `chmod +x script/build_and_run.sh`

- [ ] **Step 9: Add the Codex run action**

Write `.codex/environments/environment.toml`:

```toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "Vocra"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 10: Verify the scaffold builds and launches**

Run: `swift test`

Expected: PASS.

Run: `./script/build_and_run.sh --verify`

Expected: command exits 0 and `Vocra` is running.

- [ ] **Step 11: Commit**

```bash
git add Package.swift Sources Tests script .codex
git commit -m "feat: scaffold macOS app"
```

## Task 2: Text Classification

**Files:**
- Create: `Sources/VocraCore/Models/CapturedText.swift`
- Create: `Sources/VocraCore/Services/TextClassifier.swift`
- Create: `Tests/VocraCoreTests/TextClassifierTests.swift`

- [ ] **Step 1: Write the failing classifier tests**

Write `Tests/VocraCoreTests/TextClassifierTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class TextClassifierTests: XCTestCase {
  private let classifier = TextClassifier()

  func testClassifiesSingleTokenAsWord() {
    XCTAssertEqual(classifier.classify("embedding").mode, .word)
  }

  func testClassifiesOneSpaceAsPhrase() {
    XCTAssertEqual(classifier.classify("context window").mode, .phrase)
  }

  func testClassifiesShortTechnicalTermWithTwoSpacesAsPhrase() {
    XCTAssertEqual(classifier.classify("retrieval augmented generation").mode, .phrase)
  }

  func testClassifiesPunctuatedSelectionAsSentence() {
    XCTAssertEqual(classifier.classify("The model failed to follow the instruction.").mode, .sentence)
  }

  func testClassifiesPredicateSelectionAsSentence() {
    XCTAssertEqual(classifier.classify("this function returns a string").mode, .sentence)
  }

  func testCollapsesWhitespaceBeforeClassifying() {
    let result = classifier.classify("  large   language   model  ")
    XCTAssertEqual(result.cleanedText, "large language model")
    XCTAssertEqual(result.mode, .phrase)
  }
}
```

- [ ] **Step 2: Run the classifier tests and verify failure**

Run: `swift test --filter TextClassifierTests`

Expected: FAIL because `TextClassifier` and `CapturedText` do not exist yet.

- [ ] **Step 3: Add captured text model**

Write `Sources/VocraCore/Models/CapturedText.swift`:

```swift
import Foundation

public struct CapturedText: Equatable, Sendable {
  public let originalText: String
  public let cleanedText: String
  public let mode: ExplanationMode
  public let sourceApp: String?

  public init(originalText: String, cleanedText: String, mode: ExplanationMode, sourceApp: String? = nil) {
    self.originalText = originalText
    self.cleanedText = cleanedText
    self.mode = mode
    self.sourceApp = sourceApp
  }
}
```

- [ ] **Step 4: Add the classifier implementation**

Write `Sources/VocraCore/Services/TextClassifier.swift`:

```swift
import Foundation

public struct TextClassifier: Sendable {
  private let predicateMarkers: Set<String> = [
    "is", "are", "was", "were", "be", "been",
    "has", "have", "had",
    "can", "could", "should", "would", "will",
    "returns", "returned", "failed", "fails", "means", "refers"
  ]

  public init() {}

  public func classify(_ text: String, sourceApp: String? = nil) -> CapturedText {
    let cleaned = clean(text)
    let mode = classifyCleanedText(cleaned)
    return CapturedText(originalText: text, cleanedText: cleaned, mode: mode, sourceApp: sourceApp)
  }

  public func clean(_ text: String) -> String {
    let collapsed = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    let edgeCharacters = CharacterSet(charactersIn: "\"'`“”‘’()[]{}")
    return collapsed.trimmingCharacters(in: edgeCharacters)
  }

  private func classifyCleanedText(_ text: String) -> ExplanationMode {
    guard !text.isEmpty else { return .sentence }

    let words = text.split(separator: " ").map(String.init)
    let spaceCount = max(words.count - 1, 0)

    if spaceCount == 0 { return .word }
    if spaceCount == 1 { return .phrase }

    if hasSentencePunctuation(text) { return .sentence }
    if hasPredicateMarker(words) { return .sentence }
    if words.count <= 5 { return .phrase }

    return .sentence
  }

  private func hasSentencePunctuation(_ text: String) -> Bool {
    text.contains { character in
      ".?!;:".contains(character)
    }
  }

  private func hasPredicateMarker(_ words: [String]) -> Bool {
    words.contains { word in
      let normalized = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
      return predicateMarkers.contains(normalized)
    }
  }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter TextClassifierTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VocraCore/Models/CapturedText.swift Sources/VocraCore/Services/TextClassifier.swift Tests/VocraCoreTests/TextClassifierTests.swift
git commit -m "feat: add local text classifier"
```

## Task 3: Prompt Rendering And Defaults

**Files:**
- Create: `Sources/VocraCore/Models/PromptTemplate.swift`
- Create: `Sources/VocraCore/Services/PromptRenderer.swift`
- Create: `Sources/VocraCore/Stores/PromptStore.swift`
- Create: `Tests/VocraCoreTests/PromptRendererTests.swift`

- [ ] **Step 1: Write the failing prompt tests**

Write `Tests/VocraCoreTests/PromptRendererTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class PromptRendererTests: XCTestCase {
  func testRendersSupportedVariables() throws {
    let template = PromptTemplate(kind: .sentenceExplanation, body: "Explain {{text}} from {{sourceApp}} as {{type}}.")
    let context = PromptContext(text: "The model returns JSON.", type: .sentence, sourceApp: "Safari", surroundingContext: "", createdAt: "2026-04-26T00:00:00Z")

    let output = try PromptRenderer().render(template, context: context)

    XCTAssertEqual(output, "Explain The model returns JSON. from Safari as sentence.")
  }

  func testRejectsUnknownVariables() {
    let template = PromptTemplate(kind: .wordExplanation, body: "Explain {{unknown}}.")
    let context = PromptContext(text: "embedding", type: .word, sourceApp: nil, surroundingContext: "", createdAt: "2026-04-26T00:00:00Z")

    XCTAssertThrowsError(try PromptRenderer().render(template, context: context)) { error in
      XCTAssertEqual(error as? PromptRenderError, .unknownVariable("unknown"))
    }
  }

  func testDefaultStoreContainsFourPrompts() {
    let store = InMemoryPromptStore.defaults()
    XCTAssertNotNil(store.template(for: .wordExplanation))
    XCTAssertNotNil(store.template(for: .phraseExplanation))
    XCTAssertNotNil(store.template(for: .sentenceExplanation))
    XCTAssertNotNil(store.template(for: .vocabularyCard))
  }
}
```

- [ ] **Step 2: Run the prompt tests and verify failure**

Run: `swift test --filter PromptRendererTests`

Expected: FAIL because prompt types do not exist yet.

- [ ] **Step 3: Add prompt models**

Write `Sources/VocraCore/Models/PromptTemplate.swift`:

```swift
import Foundation

public enum PromptKind: String, CaseIterable, Codable, Equatable, Sendable {
  case wordExplanation
  case phraseExplanation
  case sentenceExplanation
  case vocabularyCard
}

public struct PromptTemplate: Codable, Equatable, Sendable {
  public let kind: PromptKind
  public var body: String

  public init(kind: PromptKind, body: String) {
    self.kind = kind
    self.body = body
  }
}

public struct PromptContext: Equatable, Sendable {
  public let text: String
  public let type: ExplanationMode
  public let sourceApp: String?
  public let surroundingContext: String
  public let createdAt: String

  public init(text: String, type: ExplanationMode, sourceApp: String?, surroundingContext: String, createdAt: String) {
    self.text = text
    self.type = type
    self.sourceApp = sourceApp
    self.surroundingContext = surroundingContext
    self.createdAt = createdAt
  }
}
```

- [ ] **Step 4: Add the prompt renderer**

Write `Sources/VocraCore/Services/PromptRenderer.swift`:

```swift
import Foundation

public enum PromptRenderError: Error, Equatable, Sendable {
  case unknownVariable(String)
}

public struct PromptRenderer: Sendable {
  private let variablePattern = #/\{\{([A-Za-z0-9_]+)\}\}/#

  public init() {}

  public func render(_ template: PromptTemplate, context: PromptContext) throws -> String {
    var output = template.body
    let values: [String: String] = [
      "text": context.text,
      "type": context.type.rawValue,
      "sourceApp": context.sourceApp ?? "Unknown App",
      "surroundingContext": context.surroundingContext,
      "createdAt": context.createdAt
    ]

    let matches = template.body.matches(of: variablePattern)
    for match in matches {
      let name = String(match.1)
      guard let value = values[name] else {
        throw PromptRenderError.unknownVariable(name)
      }
      output = output.replacingOccurrences(of: "{{\(name)}}", with: value)
    }

    return output
  }
}
```

- [ ] **Step 5: Add the prompt store**

Write `Sources/VocraCore/Stores/PromptStore.swift`:

```swift
import Foundation

public protocol PromptStore: Sendable {
  func template(for kind: PromptKind) -> PromptTemplate?
  mutating func save(_ template: PromptTemplate)
}

public struct InMemoryPromptStore: PromptStore {
  private var templates: [PromptKind: PromptTemplate]

  public init(templates: [PromptKind: PromptTemplate]) {
    self.templates = templates
  }

  public static func defaults() -> InMemoryPromptStore {
    InMemoryPromptStore(templates: [
      .wordExplanation: PromptTemplate(kind: .wordExplanation, body: "Explain this English word for a Chinese AI learner: {{text}}"),
      .phraseExplanation: PromptTemplate(kind: .phraseExplanation, body: "Explain this AI or technical English term for a Chinese learner: {{text}}"),
      .sentenceExplanation: PromptTemplate(kind: .sentenceExplanation, body: "Explain the grammar, sentence structure, and meaning of this English sentence in Chinese: {{text}}"),
      .vocabularyCard: PromptTemplate(kind: .vocabularyCard, body: "Create a Markdown vocabulary card for {{type}}: {{text}}")
    ])
  }

  public func template(for kind: PromptKind) -> PromptTemplate? {
    templates[kind]
  }

  public mutating func save(_ template: PromptTemplate) {
    templates[template.kind] = template
  }
}
```

- [ ] **Step 6: Run tests**

Run: `swift test --filter PromptRendererTests`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VocraCore/Models/PromptTemplate.swift Sources/VocraCore/Services/PromptRenderer.swift Sources/VocraCore/Stores/PromptStore.swift Tests/VocraCoreTests/PromptRendererTests.swift
git commit -m "feat: add prompt rendering"
```

## Task 4: Settings And Keychain Storage

**Files:**
- Create: `Sources/VocraCore/Models/APIConfiguration.swift`
- Create: `Sources/VocraCore/Stores/APIKeyStore.swift`
- Create: `Sources/VocraCore/Stores/SettingsStore.swift`
- Modify: `Sources/Vocra/Views/SettingsView.swift`

- [ ] **Step 1: Add API configuration model**

Write `Sources/VocraCore/Models/APIConfiguration.swift`:

```swift
import Foundation

public struct APIConfiguration: Codable, Equatable, Sendable {
  public var baseURL: URL
  public var model: String
  public var temperature: Double
  public var timeoutSeconds: Double

  public init(baseURL: URL, model: String, temperature: Double, timeoutSeconds: Double) {
    self.baseURL = baseURL
    self.model = model
    self.temperature = temperature
    self.timeoutSeconds = timeoutSeconds
  }

  public static let `default` = APIConfiguration(
    baseURL: URL(string: "https://api.openai.com/v1")!,
    model: "gpt-5.1-mini",
    temperature: 0.2,
    timeoutSeconds: 45
  )
}
```

- [ ] **Step 2: Add Keychain store**

Write `Sources/VocraCore/Stores/APIKeyStore.swift`:

```swift
import Foundation
import Security

public protocol APIKeyStore: Sendable {
  func readAPIKey() throws -> String?
  func saveAPIKey(_ key: String) throws
  func deleteAPIKey() throws
}

public enum APIKeyStoreError: Error, Equatable, Sendable {
  case keychainStatus(OSStatus)
}

public struct KeychainAPIKeyStore: APIKeyStore {
  private let service = "com.indincys.Vocra"
  private let account = "OpenAICompatibleAPIKey"

  public init() {}

  public func readAPIKey() throws -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw APIKeyStoreError.keychainStatus(status) }
    guard let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  public func saveAPIKey(_ key: String) throws {
    try deleteAPIKey()
    var item = baseQuery()
    item[kSecValueData as String] = Data(key.utf8)
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw APIKeyStoreError.keychainStatus(status) }
  }

  public func deleteAPIKey() throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw APIKeyStoreError.keychainStatus(status)
    }
  }

  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}
```

- [ ] **Step 3: Add settings store**

Write `Sources/VocraCore/Stores/SettingsStore.swift`:

```swift
import Foundation

public protocol SettingsStore: Sendable {
  func loadAPIConfiguration() -> APIConfiguration
  func saveAPIConfiguration(_ configuration: APIConfiguration)
}

public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let apiConfigurationKey = "apiConfiguration"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func loadAPIConfiguration() -> APIConfiguration {
    guard
      let data = defaults.data(forKey: apiConfigurationKey),
      let configuration = try? JSONDecoder().decode(APIConfiguration.self, from: data)
    else {
      return .default
    }
    return configuration
  }

  public func saveAPIConfiguration(_ configuration: APIConfiguration) {
    guard let data = try? JSONEncoder().encode(configuration) else { return }
    defaults.set(data, forKey: apiConfigurationKey)
  }
}
```

- [ ] **Step 4: Add a settings UI shell**

Write `Sources/Vocra/Views/SettingsView.swift`:

```swift
import AppKit
import SwiftUI
import VocraCore

struct SettingsView: View {
  @State private var baseURL = APIConfiguration.default.baseURL.absoluteString
  @State private var model = APIConfiguration.default.model
  @State private var temperature = APIConfiguration.default.temperature
  @State private var timeout = APIConfiguration.default.timeoutSeconds
  @State private var apiKey = ""

  var body: some View {
    Form {
      Section("API") {
        TextField("Base URL", text: $baseURL)
        TextField("Model", text: $model)
        SecureField("API Key", text: $apiKey)

        HStack {
          Text("Temperature")
          Slider(value: $temperature, in: 0...2, step: 0.1)
          Text(temperature.formatted(.number.precision(.fractionLength(1))))
            .monospacedDigit()
            .frame(width: 36, alignment: .trailing)
        }

        HStack {
          Text("Timeout")
          Stepper("\(Int(timeout)) seconds", value: $timeout, in: 5...120, step: 5)
        }

        Button("Test Connection") {}
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 520)
  }
}
```

- [ ] **Step 5: Wire settings scene**

Modify `Sources/Vocra/App/VocraApp.swift` so the scene body includes:

```swift
Settings {
  SettingsView()
}
```

Keep the existing `MenuBarExtra` and `WindowGroup`.

- [ ] **Step 6: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VocraCore/Models/APIConfiguration.swift Sources/VocraCore/Stores/APIKeyStore.swift Sources/VocraCore/Stores/SettingsStore.swift Sources/Vocra/Views/SettingsView.swift Sources/Vocra/App/VocraApp.swift
git commit -m "feat: add API settings storage"
```

## Task 5: OpenAI-Compatible API Client

**Files:**
- Create: `Sources/VocraCore/Services/AIClient.swift`
- Create: `Sources/VocraCore/Services/OpenAICompatibleClient.swift`
- Create: `Tests/VocraCoreTests/AIClientTests.swift`

- [ ] **Step 1: Write the failing API client tests**

Write `Tests/VocraCoreTests/AIClientTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class AIClientTests: XCTestCase {
  func testBuildsChatCompletionRequestAndParsesContent() async throws {
    let http = StubHTTPClient(responseData: Data("""
    {"choices":[{"message":{"content":"## Meaning\\nA vector representation."}}]}
    """.utf8))
    let configuration = APIConfiguration(baseURL: URL(string: "https://example.com/v1")!, model: "model-a", temperature: 0.3, timeoutSeconds: 10)
    let client = OpenAICompatibleClient(configuration: configuration, apiKeyProvider: { "secret" }, httpClient: http)

    let content = try await client.complete(prompt: "Explain embedding")

    XCTAssertEqual(content, "## Meaning\nA vector representation.")
    XCTAssertEqual(http.lastRequest?.url?.absoluteString, "https://example.com/v1/chat/completions")
    XCTAssertEqual(http.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
  }
}

private final class StubHTTPClient: HTTPClient, @unchecked Sendable {
  var lastRequest: URLRequest?
  let responseData: Data

  init(responseData: Data) {
    self.responseData = responseData
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    lastRequest = request
    return (responseData, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
  }
}
```

- [ ] **Step 2: Run the API tests and verify failure**

Run: `swift test --filter AIClientTests`

Expected: FAIL because `OpenAICompatibleClient` does not exist yet.

- [ ] **Step 3: Add client protocol**

Write `Sources/VocraCore/Services/AIClient.swift`:

```swift
import Foundation

public protocol AIClient: Sendable {
  func complete(prompt: String) async throws -> String
}

public enum AIClientError: Error, Equatable, Sendable {
  case missingAPIKey
  case invalidResponse
  case httpStatus(Int)
  case emptyContent
}
```

- [ ] **Step 4: Add OpenAI-compatible implementation**

Write `Sources/VocraCore/Services/OpenAICompatibleClient.swift`:

```swift
import Foundation

public protocol HTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await data(for: request, delegate: nil)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AIClientError.invalidResponse
    }
    return (data, httpResponse)
  }
}

public struct OpenAICompatibleClient: AIClient {
  private let configuration: APIConfiguration
  private let apiKeyProvider: @Sendable () throws -> String?
  private let httpClient: HTTPClient

  public init(configuration: APIConfiguration, apiKeyProvider: @escaping @Sendable () throws -> String?, httpClient: HTTPClient = URLSession.shared) {
    self.configuration = configuration
    self.apiKeyProvider = apiKeyProvider
    self.httpClient = httpClient
  }

  public func complete(prompt: String) async throws -> String {
    guard let apiKey = try apiKeyProvider(), !apiKey.isEmpty else {
      throw AIClientError.missingAPIKey
    }

    var request = URLRequest(url: configuration.baseURL.appending(path: "chat/completions"))
    request.httpMethod = "POST"
    request.timeoutInterval = configuration.timeoutSeconds
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(ChatRequest(
      model: configuration.model,
      temperature: configuration.temperature,
      messages: [ChatMessage(role: "user", content: prompt)]
    ))

    let (data, response) = try await httpClient.data(for: request)
    guard (200..<300).contains(response.statusCode) else {
      throw AIClientError.httpStatus(response.statusCode)
    }

    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
    guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
      throw AIClientError.emptyContent
    }
    return content
  }
}

private struct ChatRequest: Encodable {
  let model: String
  let temperature: Double
  let messages: [ChatMessage]
}

private struct ChatMessage: Codable {
  let role: String
  let content: String
}

private struct ChatResponse: Decodable {
  let choices: [Choice]

  struct Choice: Decodable {
    let message: ChatMessage
  }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter AIClientTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VocraCore/Services/AIClient.swift Sources/VocraCore/Services/OpenAICompatibleClient.swift Tests/VocraCoreTests/AIClientTests.swift
git commit -m "feat: add OpenAI-compatible client"
```

## Task 6: Review Scheduling And Vocabulary Models

**Files:**
- Create: `Sources/VocraCore/Models/VocabularyCard.swift`
- Create: `Sources/VocraCore/Services/ReviewScheduler.swift`
- Create: `Tests/VocraCoreTests/ReviewSchedulerTests.swift`

- [ ] **Step 1: Write failing scheduler tests**

Write `Tests/VocraCoreTests/ReviewSchedulerTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class ReviewSchedulerTests: XCTestCase {
  func testForgotSchedulesTomorrow() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let result = ReviewScheduler().schedule(after: .forgot, now: now)
    XCTAssertEqual(result.status, .learning)
    XCTAssertEqual(result.nextReviewAt, Calendar.current.date(byAdding: .day, value: 1, to: now))
  }

  func testVagueSchedulesThreeDaysLater() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let result = ReviewScheduler().schedule(after: .vague, now: now)
    XCTAssertEqual(result.nextReviewAt, Calendar.current.date(byAdding: .day, value: 3, to: now))
  }

  func testFamiliarSchedulesTenDaysLater() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let result = ReviewScheduler().schedule(after: .familiar, now: now)
    XCTAssertEqual(result.nextReviewAt, Calendar.current.date(byAdding: .day, value: 10, to: now))
  }

  func testMasteredRemovesFromActiveReview() {
    let result = ReviewScheduler().schedule(after: .mastered, now: Date(timeIntervalSince1970: 1_800_000_000))
    XCTAssertEqual(result.status, .mastered)
    XCTAssertNil(result.nextReviewAt)
  }
}
```

- [ ] **Step 2: Run scheduler tests and verify failure**

Run: `swift test --filter ReviewSchedulerTests`

Expected: FAIL because scheduler types do not exist yet.

- [ ] **Step 3: Add vocabulary model**

Write `Sources/VocraCore/Models/VocabularyCard.swift`:

```swift
import Foundation

public enum VocabularyType: String, Codable, Equatable, Sendable {
  case word
  case phrase
}

public enum VocabularyStatus: String, Codable, Equatable, Sendable {
  case new
  case learning
  case familiar
  case mastered
}

public enum ReviewRating: String, Codable, Equatable, Sendable {
  case forgot
  case vague
  case familiar
  case mastered
}

public struct VocabularyCard: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var text: String
  public var type: VocabularyType
  public var cardMarkdown: String
  public var sourceApp: String?
  public var createdAt: Date
  public var updatedAt: Date
  public var lastReviewedAt: Date?
  public var nextReviewAt: Date?
  public var reviewCount: Int
  public var status: VocabularyStatus
  public var familiarityLevel: Int

  public init(id: UUID = UUID(), text: String, type: VocabularyType, cardMarkdown: String, sourceApp: String?, createdAt: Date, updatedAt: Date, lastReviewedAt: Date?, nextReviewAt: Date?, reviewCount: Int, status: VocabularyStatus, familiarityLevel: Int) {
    self.id = id
    self.text = text
    self.type = type
    self.cardMarkdown = cardMarkdown
    self.sourceApp = sourceApp
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.lastReviewedAt = lastReviewedAt
    self.nextReviewAt = nextReviewAt
    self.reviewCount = reviewCount
    self.status = status
    self.familiarityLevel = familiarityLevel
  }
}
```

- [ ] **Step 4: Add scheduler**

Write `Sources/VocraCore/Services/ReviewScheduler.swift`:

```swift
import Foundation

public struct ReviewScheduleResult: Equatable, Sendable {
  public let status: VocabularyStatus
  public let familiarityLevel: Int
  public let nextReviewAt: Date?
}

public struct ReviewScheduler: Sendable {
  public init() {}

  public func schedule(after rating: ReviewRating, now: Date) -> ReviewScheduleResult {
    switch rating {
    case .forgot:
      ReviewScheduleResult(status: .learning, familiarityLevel: 0, nextReviewAt: Calendar.current.date(byAdding: .day, value: 1, to: now))
    case .vague:
      ReviewScheduleResult(status: .learning, familiarityLevel: 1, nextReviewAt: Calendar.current.date(byAdding: .day, value: 3, to: now))
    case .familiar:
      ReviewScheduleResult(status: .familiar, familiarityLevel: 2, nextReviewAt: Calendar.current.date(byAdding: .day, value: 10, to: now))
    case .mastered:
      ReviewScheduleResult(status: .mastered, familiarityLevel: 3, nextReviewAt: nil)
    }
  }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter ReviewSchedulerTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VocraCore/Models/VocabularyCard.swift Sources/VocraCore/Services/ReviewScheduler.swift Tests/VocraCoreTests/ReviewSchedulerTests.swift
git commit -m "feat: add review scheduling"
```

## Task 7: SQLite Vocabulary Repository

**Files:**
- Create: `Sources/VocraCore/Support/SQLiteDatabase.swift`
- Create: `Sources/VocraCore/Stores/VocabularyRepository.swift`
- Create: `Tests/VocraCoreTests/VocabularyRepositoryTests.swift`

- [ ] **Step 1: Write failing repository tests**

Write `Tests/VocraCoreTests/VocabularyRepositoryTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class VocabularyRepositoryTests: XCTestCase {
  func testUpsertCreatesAndDeduplicatesByNormalizedText() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    let first = try repository.upsert(text: "Context Window", type: .phrase, cardMarkdown: "Card A", sourceApp: "Safari", now: now)
    let second = try repository.upsert(text: " context   window ", type: .phrase, cardMarkdown: "Card B", sourceApp: "Codex", now: now)

    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(try repository.allCards().count, 1)
    XCTAssertEqual(try repository.allCards().first?.sourceApp, "Codex")
  }

  func testDueCardsExcludeMasteredCards() throws {
    let repository = try SQLiteVocabularyRepository.inMemory()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let card = try repository.upsert(text: "embedding", type: .word, cardMarkdown: "Card", sourceApp: nil, now: now)

    try repository.applyReview(cardID: card.id, rating: .mastered, now: now, scheduler: ReviewScheduler())

    XCTAssertTrue(try repository.dueCards(now: now).isEmpty)
  }
}
```

- [ ] **Step 2: Run repository tests and verify failure**

Run: `swift test --filter VocabularyRepositoryTests`

Expected: FAIL because repository types do not exist yet.

- [ ] **Step 3: Add SQLite helper**

Write `Sources/VocraCore/Support/SQLiteDatabase.swift`:

```swift
import Foundation
import SQLite3

public final class SQLiteDatabase {
  private var handle: OpaquePointer?

  public init(path: String) throws {
    guard sqlite3_open(path, &handle) == SQLITE_OK else {
      throw SQLiteError.open(String(cString: sqlite3_errmsg(handle)))
    }
  }

  deinit {
    sqlite3_close(handle)
  }

  public func execute(_ sql: String) throws {
    guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
      throw SQLiteError.execute(String(cString: sqlite3_errmsg(handle)))
    }
  }

  public func prepare(_ sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
      throw SQLiteError.prepare(String(cString: sqlite3_errmsg(handle)))
    }
    return statement
  }
}

public enum SQLiteError: Error, Equatable, Sendable {
  case open(String)
  case execute(String)
  case prepare(String)
  case step(String)
}
```

- [ ] **Step 4: Add repository implementation**

Write `Sources/VocraCore/Stores/VocabularyRepository.swift`:

```swift
import Foundation
import SQLite3

public protocol VocabularyRepository: Sendable {
  func allCards() throws -> [VocabularyCard]
  func dueCards(now: Date) throws -> [VocabularyCard]
  func upsert(text: String, type: VocabularyType, cardMarkdown: String, sourceApp: String?, now: Date) throws -> VocabularyCard
  func applyReview(cardID: UUID, rating: ReviewRating, now: Date, scheduler: ReviewScheduler) throws
}

public final class SQLiteVocabularyRepository: VocabularyRepository, @unchecked Sendable {
  private let database: SQLiteDatabase

  public init(path: String) throws {
    self.database = try SQLiteDatabase(path: path)
    try migrate()
  }

  public static func inMemory() throws -> SQLiteVocabularyRepository {
    try SQLiteVocabularyRepository(path: ":memory:")
  }

  public func allCards() throws -> [VocabularyCard] {
    try fetchCards(whereClause: "1 = 1", bindings: [])
  }

  public func dueCards(now: Date) throws -> [VocabularyCard] {
    try fetchCards(whereClause: "status != 'mastered' AND nextReviewAt IS NOT NULL AND nextReviewAt <= ?", bindings: [.double(now.timeIntervalSince1970)])
  }

  public func upsert(text: String, type: VocabularyType, cardMarkdown: String, sourceApp: String?, now: Date) throws -> VocabularyCard {
    let normalized = normalize(text)
    if var existing = try card(normalizedText: normalized) {
      existing.cardMarkdown = cardMarkdown
      existing.sourceApp = sourceApp
      existing.updatedAt = now
      try save(existing, normalizedText: normalized)
      return existing
    }

    let card = VocabularyCard(
      text: text.trimmingCharacters(in: .whitespacesAndNewlines),
      type: type,
      cardMarkdown: cardMarkdown,
      sourceApp: sourceApp,
      createdAt: now,
      updatedAt: now,
      lastReviewedAt: nil,
      nextReviewAt: now,
      reviewCount: 0,
      status: .new,
      familiarityLevel: 0
    )
    try insert(card, normalizedText: normalized)
    return card
  }

  public func applyReview(cardID: UUID, rating: ReviewRating, now: Date, scheduler: ReviewScheduler) throws {
    guard var card = try card(id: cardID) else { return }
    let result = scheduler.schedule(after: rating, now: now)
    card.lastReviewedAt = now
    card.nextReviewAt = result.nextReviewAt
    card.reviewCount += 1
    card.status = result.status
    card.familiarityLevel = result.familiarityLevel
    card.updatedAt = now
    try save(card, normalizedText: normalize(card.text))
  }

  private func migrate() throws {
    try database.execute("""
    CREATE TABLE IF NOT EXISTS vocabulary_cards (
      id TEXT PRIMARY KEY,
      normalizedText TEXT UNIQUE NOT NULL,
      text TEXT NOT NULL,
      type TEXT NOT NULL,
      cardMarkdown TEXT NOT NULL,
      sourceApp TEXT,
      createdAt REAL NOT NULL,
      updatedAt REAL NOT NULL,
      lastReviewedAt REAL,
      nextReviewAt REAL,
      reviewCount INTEGER NOT NULL,
      status TEXT NOT NULL,
      familiarityLevel INTEGER NOT NULL
    );
    """)
  }

  private func normalize(_ text: String) -> String {
    text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .lowercased()
  }

  private func insert(_ card: VocabularyCard, normalizedText: String) throws {
    try executeSave(card, normalizedText: normalizedText, sql: """
    INSERT INTO vocabulary_cards
    (id, normalizedText, text, type, cardMarkdown, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """)
  }

  private func save(_ card: VocabularyCard, normalizedText: String) throws {
    try executeSave(card, normalizedText: normalizedText, sql: """
    REPLACE INTO vocabulary_cards
    (id, normalizedText, text, type, cardMarkdown, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """)
  }

  private func executeSave(_ card: VocabularyCard, normalizedText: String, sql: String) throws {
    let statement = try database.prepare(sql)
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, card.id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 2, normalizedText, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 3, card.text, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 4, card.type.rawValue, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 5, card.cardMarkdown, -1, SQLITE_TRANSIENT)
    bindOptionalText(statement, 6, card.sourceApp)
    sqlite3_bind_double(statement, 7, card.createdAt.timeIntervalSince1970)
    sqlite3_bind_double(statement, 8, card.updatedAt.timeIntervalSince1970)
    bindOptionalDate(statement, 9, card.lastReviewedAt)
    bindOptionalDate(statement, 10, card.nextReviewAt)
    sqlite3_bind_int(statement, 11, Int32(card.reviewCount))
    sqlite3_bind_text(statement, 12, card.status.rawValue, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(statement, 13, Int32(card.familiarityLevel))
    guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.step("save vocabulary card failed") }
  }

  private func card(id: UUID) throws -> VocabularyCard? {
    try fetchCards(whereClause: "id = ?", bindings: [.text(id.uuidString)]).first
  }

  private func card(normalizedText: String) throws -> VocabularyCard? {
    try fetchCards(whereClause: "normalizedText = ?", bindings: [.text(normalizedText)]).first
  }

  private enum Binding {
    case text(String)
    case double(Double)
  }

  private func fetchCards(whereClause: String, bindings: [Binding]) throws -> [VocabularyCard] {
    let statement = try database.prepare("SELECT id, text, type, cardMarkdown, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel FROM vocabulary_cards WHERE \(whereClause) ORDER BY updatedAt DESC;")
    defer { sqlite3_finalize(statement) }

    for (index, binding) in bindings.enumerated() {
      let position = Int32(index + 1)
      switch binding {
      case .text(let value): sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
      case .double(let value): sqlite3_bind_double(statement, position, value)
      }
    }

    var cards: [VocabularyCard] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      cards.append(readCard(from: statement))
    }
    return cards
  }

  private func readCard(from statement: OpaquePointer?) -> VocabularyCard {
    VocabularyCard(
      id: UUID(uuidString: text(statement, 0))!,
      text: text(statement, 1),
      type: VocabularyType(rawValue: text(statement, 2))!,
      cardMarkdown: text(statement, 3),
      sourceApp: optionalText(statement, 4),
      createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
      updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
      lastReviewedAt: optionalDate(statement, 7),
      nextReviewAt: optionalDate(statement, 8),
      reviewCount: Int(sqlite3_column_int(statement, 9)),
      status: VocabularyStatus(rawValue: text(statement, 10))!,
      familiarityLevel: Int(sqlite3_column_int(statement, 11))
    )
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
  String(cString: sqlite3_column_text(statement, column))
}

private func optionalText(_ statement: OpaquePointer?, _ column: Int32) -> String? {
  guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
  return text(statement, column)
}

private func optionalDate(_ statement: OpaquePointer?, _ column: Int32) -> Date? {
  guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
  return Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
}

private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
  guard let value else {
    sqlite3_bind_null(statement, index)
    return
  }
  sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
}

private func bindOptionalDate(_ statement: OpaquePointer?, _ index: Int32, _ value: Date?) {
  guard let value else {
    sqlite3_bind_null(statement, index)
    return
  }
  sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
}
```

- [ ] **Step 5: Run repository tests**

Run: `swift test --filter VocabularyRepositoryTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VocraCore/Support/SQLiteDatabase.swift Sources/VocraCore/Stores/VocabularyRepository.swift Tests/VocraCoreTests/VocabularyRepositoryTests.swift
git commit -m "feat: add SQLite vocabulary repository"
```

## Task 8: Selection Reading And Global Shortcut Interfaces

**Files:**
- Create: `Sources/VocraCore/Services/SelectionReader.swift`
- Create: `Sources/VocraCore/Services/ShortcutService.swift`

- [ ] **Step 1: Add selection reader interfaces and implementation**

Write `Sources/VocraCore/Services/SelectionReader.swift`:

```swift
import AppKit
import ApplicationServices
import Foundation

public protocol SelectionReader: Sendable {
  func readSelection() async throws -> CapturedTextSelection
}

public struct CapturedTextSelection: Equatable, Sendable {
  public let text: String
  public let sourceApp: String?

  public init(text: String, sourceApp: String?) {
    self.text = text
    self.sourceApp = sourceApp
  }
}

public enum SelectionReaderError: Error, Equatable, Sendable {
  case accessibilityPermissionMissing
  case emptySelection
}

public final class MacSelectionReader: SelectionReader, @unchecked Sendable {
  public init() {}

  public func readSelection() async throws -> CapturedTextSelection {
    if !AXIsProcessTrusted() {
      throw SelectionReaderError.accessibilityPermissionMissing
    }

    if let selected = readAccessibilitySelection(), !selected.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return selected
    }

    if let copied = await readClipboardFallback(), !copied.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return copied
    }

    throw SelectionReaderError.emptySelection
  }

  private func readAccessibilitySelection() -> CapturedTextSelection? {
    let systemWide = AXUIElementCreateSystemWide()
    var focusedValue: AnyObject?
    guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success else {
      return nil
    }

    let focused = focusedValue as! AXUIElement
    var selectedValue: AnyObject?
    guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedValue) == .success else {
      return nil
    }

    guard let text = selectedValue as? String else { return nil }
    return CapturedTextSelection(text: text, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName)
  }

  @MainActor
  private func readClipboardFallback() async -> CapturedTextSelection? {
    let pasteboard = NSPasteboard.general
    let previousString = pasteboard.string(forType: .string)
    let previousChangeCount = pasteboard.changeCount

    sendCopyShortcut()
    try? await Task.sleep(for: .milliseconds(180))

    guard pasteboard.changeCount != previousChangeCount, let copied = pasteboard.string(forType: .string) else {
      return nil
    }

    if let previousString {
      pasteboard.clearContents()
      pasteboard.setString(previousString, forType: .string)
    }

    return CapturedTextSelection(text: copied, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName)
  }

  @MainActor
  private func sendCopyShortcut() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }
}
```

- [ ] **Step 2: Add global shortcut service**

Write `Sources/VocraCore/Services/ShortcutService.swift`:

```swift
import Carbon
import Foundation

public struct KeyboardShortcut: Equatable, Sendable {
  public let keyCode: UInt32
  public let modifiers: UInt32

  public init(keyCode: UInt32, modifiers: UInt32) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public static let defaultShortcut = KeyboardShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
}

public final class ShortcutService: @unchecked Sendable {
  private var hotKeyRef: EventHotKeyRef?
  private var handler: (() -> Void)?

  public init() {}

  deinit {
    unregister()
  }

  public func register(shortcut: KeyboardShortcut = .defaultShortcut, handler: @escaping () -> Void) {
    unregister()
    self.handler = handler

    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
      guard let userData else { return noErr }
      let service = Unmanaged<ShortcutService>.fromOpaque(userData).takeUnretainedValue()
      service.handler?()
      return noErr
    }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

    var hotKeyID = EventHotKeyID(signature: OSType(0x566F6372), id: 1)
    RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
  }

  public func unregister() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }
}
```

- [ ] **Step 3: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/VocraCore/Services/SelectionReader.swift Sources/VocraCore/Services/ShortcutService.swift
git commit -m "feat: add selection reader and shortcut service"
```

## Task 9: Explanation Coordinator And Vocabulary Capture Flow

**Files:**
- Create: `Sources/Vocra/App/AppModel.swift`
- Modify: `Sources/Vocra/App/VocraApp.swift`
- Modify: `Sources/Vocra/Views/RootView.swift`

- [ ] **Step 1: Add app model**

Write `Sources/Vocra/App/AppModel.swift`:

```swift
import Foundation
import Observation
import VocraCore

@MainActor
@Observable
final class AppModel {
  var latestCapturedText: CapturedText?
  var latestMarkdown: String = ""
  var latestErrorMessage: String?
  var isShortcutPaused = false

  private let classifier: TextClassifier
  private let promptRenderer: PromptRenderer
  private var promptStore: InMemoryPromptStore
  private let settingsStore: UserDefaultsSettingsStore
  private let apiKeyStore: KeychainAPIKeyStore
  private let selectionReader: SelectionReader
  private let vocabularyRepository: SQLiteVocabularyRepository
  private let reviewScheduler: ReviewScheduler
  private let shortcutService: ShortcutService

  init() {
    self.classifier = TextClassifier()
    self.promptRenderer = PromptRenderer()
    self.promptStore = .defaults()
    self.settingsStore = UserDefaultsSettingsStore()
    self.apiKeyStore = KeychainAPIKeyStore()
    self.selectionReader = MacSelectionReader()
    self.vocabularyRepository = try! SQLiteVocabularyRepository(path: AppModel.databasePath())
    self.reviewScheduler = ReviewScheduler()
    self.shortcutService = ShortcutService()
  }

  func start() {
    shortcutService.register { [weak self] in
      Task { @MainActor in
        await self?.handleShortcut()
      }
    }
  }

  func pauseShortcutListening(_ paused: Bool) {
    isShortcutPaused = paused
  }

  func handleShortcut() async {
    guard !isShortcutPaused else { return }
    do {
      let selection = try await selectionReader.readSelection()
      let captured = classifier.classify(selection.text, sourceApp: selection.sourceApp)
      latestCapturedText = captured
      let markdown = try await explain(captured)
      latestMarkdown = markdown

      if captured.mode == .word || captured.mode == .phrase {
        let vocabularyType: VocabularyType = captured.mode == .word ? .word : .phrase
        _ = try vocabularyRepository.upsert(
          text: captured.cleanedText,
          type: vocabularyType,
          cardMarkdown: markdown,
          sourceApp: captured.sourceApp,
          now: Date()
        )
      }
    } catch {
      latestErrorMessage = String(describing: error)
    }
  }

  func explainWithMode(_ mode: ExplanationMode) async {
    guard let current = latestCapturedText else { return }
    let adjusted = CapturedText(originalText: current.originalText, cleanedText: current.cleanedText, mode: mode, sourceApp: current.sourceApp)
    latestCapturedText = adjusted
    do {
      latestMarkdown = try await explain(adjusted)
    } catch {
      latestErrorMessage = String(describing: error)
    }
  }

  func dueCards() -> [VocabularyCard] {
    (try? vocabularyRepository.dueCards(now: Date())) ?? []
  }

  func applyReview(cardID: UUID, rating: ReviewRating) {
    try? vocabularyRepository.applyReview(cardID: cardID, rating: rating, now: Date(), scheduler: reviewScheduler)
  }

  private func explain(_ captured: CapturedText) async throws -> String {
    let kind: PromptKind = switch captured.mode {
    case .word: .wordExplanation
    case .phrase: .phraseExplanation
    case .sentence: .sentenceExplanation
    }
    let template = promptStore.template(for: kind)!
    let context = PromptContext(
      text: captured.cleanedText,
      type: captured.mode,
      sourceApp: captured.sourceApp,
      surroundingContext: "",
      createdAt: ISO8601DateFormatter().string(from: Date())
    )
    let prompt = try promptRenderer.render(template, context: context)
    let apiKeyStore = self.apiKeyStore
    let client = OpenAICompatibleClient(
      configuration: settingsStore.loadAPIConfiguration(),
      apiKeyProvider: { try apiKeyStore.readAPIKey() }
    )
    return try await client.complete(prompt: prompt)
  }

  private static func databasePath() -> String {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let folder = support.appending(path: "Vocra", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appending(path: "vocra.sqlite").path
  }
}
```

- [ ] **Step 2: Inject app model into scenes**

Modify `Sources/Vocra/App/VocraApp.swift`:

```swift
import SwiftUI

@main
struct VocraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

      Divider()

      Button("Open Vocra") {
        NSApp.activate(ignoringOtherApps: true)
      }

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
```

- [ ] **Step 3: Update root view initializer**

Modify `Sources/Vocra/Views/RootView.swift`:

```swift
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

        if !appModel.latestMarkdown.isEmpty {
          ScrollView {
            Text(tryAttributedMarkdown(appModel.latestMarkdown))
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
```

- [ ] **Step 4: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Vocra/App/AppModel.swift Sources/Vocra/App/VocraApp.swift Sources/Vocra/Views/RootView.swift
git commit -m "feat: connect shortcut explanation flow"
```

## Task 10: Liquid Glass Floating Panel

**Files:**
- Create: `Sources/Vocra/Support/FloatingPanelController.swift`
- Create: `Sources/Vocra/Views/ExplanationPanelView.swift`
- Modify: `Sources/Vocra/App/AppModel.swift`

- [ ] **Step 1: Add SwiftUI panel view**

Write `Sources/Vocra/Views/ExplanationPanelView.swift`:

```swift
import AppKit
import SwiftUI
import VocraCore

struct ExplanationPanelView: View {
  let capturedText: CapturedText?
  let markdown: String
  let errorMessage: String?
  let onSwitchMode: (ExplanationMode) -> Void
  let onClose: () -> Void

  var body: some View {
    GlassEffectContainer {
      VStack(alignment: .leading, spacing: 14) {
        header

        Divider()
          .opacity(0.35)

        ScrollView {
          if let errorMessage {
            Text(errorMessage)
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else if markdown.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity, minHeight: 320)
          } else {
            Text(renderedMarkdown)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        footer
      }
      .padding(20)
      .frame(width: 480, height: 520)
      .foregroundStyle(.primary)
      .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
  }

  private var header: some View {
    HStack {
      Text(capturedText?.mode.displayName ?? "Vocra")
        .font(.headline)

      Spacer()

      Picker("Mode", selection: Binding(
        get: { capturedText?.mode ?? .sentence },
        set: { onSwitchMode($0) }
      )) {
        Text("Word").tag(ExplanationMode.word)
        Text("Term").tag(ExplanationMode.phrase)
        Text("Sentence").tag(ExplanationMode.sentence)
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 220)

      Button {
        onClose()
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(.glass)
    }
  }

  private var footer: some View {
    HStack {
      Button("Copy") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
      }
      .buttonStyle(.glass)

      Spacer()
    }
  }

  private var renderedMarkdown: AttributedString {
    (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
  }
}
```

- [ ] **Step 2: Add AppKit floating panel bridge**

Write `Sources/Vocra/Support/FloatingPanelController.swift`:

```swift
import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
  private var panel: NSPanel?
  private let autosaveName = "VocraExplanationPanelFrame"

  func show<Content: View>(rootView: Content) {
    let panel = existingOrCreatePanel()
    panel.contentView = NSHostingView(rootView: rootView)
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    panel?.orderOut(nil)
  }

  private func existingOrCreatePanel() -> NSPanel {
    if let panel { return panel }

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
      styleMask: [.borderless, .resizable, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = true
    panel.setFrameAutosaveName(autosaveName)
    panel.center()
    self.panel = panel
    return panel
  }
}
```

- [ ] **Step 3: Show panel from app model**

Modify `Sources/Vocra/App/AppModel.swift`:

```swift
private let floatingPanel = FloatingPanelController()

private func refreshPanel() {
  floatingPanel.show(rootView: ExplanationPanelView(
    capturedText: latestCapturedText,
    markdown: latestMarkdown,
    errorMessage: latestErrorMessage,
    onSwitchMode: { [weak self] mode in
      Task { @MainActor in
        await self?.explainWithMode(mode)
      }
    },
    onClose: { [weak self] in
      self?.floatingPanel.close()
    }
  ))
}
```

Call `refreshPanel()` immediately after setting `latestCapturedText`, after setting `latestMarkdown`, and after setting `latestErrorMessage`.

- [ ] **Step 4: Build and launch**

Run: `swift build`

Expected: PASS.

Run: `./script/build_and_run.sh --verify`

Expected: command exits 0 and app is running.

- [ ] **Step 5: Manual check**

Open the app, choose `Explain Selection` from the menu bar with no API key configured, and verify the transparent panel appears with an error message instead of crashing.

- [ ] **Step 6: Commit**

```bash
git add Sources/Vocra/Support/FloatingPanelController.swift Sources/Vocra/Views/ExplanationPanelView.swift Sources/Vocra/App/AppModel.swift
git commit -m "feat: add Liquid Glass explanation panel"
```

## Task 11: Main Window Vocabulary And Review UI

**Files:**
- Create: `Sources/Vocra/Views/VocabularyListView.swift`
- Create: `Sources/Vocra/Views/ReviewView.swift`
- Modify: `Sources/Vocra/Views/RootView.swift`
- Modify: `Sources/Vocra/App/AppModel.swift`

- [ ] **Step 1: Add vocabulary list view**

Write `Sources/Vocra/Views/VocabularyListView.swift`:

```swift
import SwiftUI
import VocraCore

struct VocabularyListView: View {
  let cards: [VocabularyCard]

  var body: some View {
    List(cards) { card in
      VStack(alignment: .leading, spacing: 4) {
        Text(card.text)
          .font(.headline)
        Text(card.status.rawValue.capitalized)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
```

- [ ] **Step 2: Add review view**

Write `Sources/Vocra/Views/ReviewView.swift`:

```swift
import SwiftUI
import VocraCore

struct ReviewView: View {
  let cards: [VocabularyCard]
  let onRate: (UUID, ReviewRating) -> Void
  @State private var index = 0
  @State private var showsBack = false

  var body: some View {
    VStack(spacing: 20) {
      if cards.isEmpty {
        ContentUnavailableView("No Due Cards", systemImage: "checkmark.circle", description: Text("Vocabulary due for review will appear here."))
      } else {
        let card = cards[min(index, cards.count - 1)]

        Button {
          showsBack.toggle()
        } label: {
          VStack(spacing: 16) {
            Text(card.text)
              .font(.largeTitle)
              .fontWeight(.semibold)

            if showsBack {
              Text(renderedMarkdown(card.cardMarkdown))
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(32)
          .frame(maxWidth: 560, minHeight: 320)
        }
        .buttonStyle(.plain)

        HStack {
          reviewButton("Forgot", .forgot, card.id)
          reviewButton("Vague", .vague, card.id)
          reviewButton("Familiar", .familiar, card.id)
          reviewButton("Mastered", .mastered, card.id)
        }
      }
    }
    .padding()
  }

  private func reviewButton(_ title: String, _ rating: ReviewRating, _ cardID: UUID) -> some View {
    Button(title) {
      onRate(cardID, rating)
      showsBack = false
      index += 1
    }
    .buttonStyle(.glass)
  }

  private func renderedMarkdown(_ markdown: String) -> AttributedString {
    (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
  }
}
```

- [ ] **Step 3: Add card loading methods**

Modify `Sources/Vocra/App/AppModel.swift` by adding:

```swift
var allVocabularyCards: [VocabularyCard] {
  (try? vocabularyRepository.allCards()) ?? []
}
```

- [ ] **Step 4: Update root view with tabs**

Modify `Sources/Vocra/Views/RootView.swift` detail area to use:

```swift
TabView {
  VocabularyListView(cards: appModel.allVocabularyCards)
    .tabItem { Label("Vocabulary", systemImage: "text.book.closed") }

  ReviewView(cards: appModel.dueCards()) { cardID, rating in
    appModel.applyReview(cardID: cardID, rating: rating)
  }
  .tabItem { Label("Review", systemImage: "rectangle.on.rectangle") }

  SettingsView()
    .tabItem { Label("Settings", systemImage: "gearshape") }
}
```

- [ ] **Step 5: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/Vocra/Views/VocabularyListView.swift Sources/Vocra/Views/ReviewView.swift Sources/Vocra/Views/RootView.swift Sources/Vocra/App/AppModel.swift
git commit -m "feat: add vocabulary and review views"
```

## Task 12: Persistent Prompt Management

**Files:**
- Modify: `Sources/VocraCore/Stores/PromptStore.swift`
- Create: `Tests/VocraCoreTests/PromptStoreTests.swift`
- Modify: `Sources/Vocra/App/AppModel.swift`
- Modify: `Sources/Vocra/Views/SettingsView.swift`

- [ ] **Step 1: Write failing prompt store tests**

Write `Tests/VocraCoreTests/PromptStoreTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class PromptStoreTests: XCTestCase {
  func testUserDefaultsPromptStorePersistsCustomPrompt() {
    let suiteName = "PromptStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    var store = UserDefaultsPromptStore(defaults: defaults)
    let replacement = PromptTemplate(kind: .sentenceExplanation, body: "Custom sentence prompt for {{text}}")
    store.save(replacement)

    let reloaded = UserDefaultsPromptStore(defaults: defaults)

    XCTAssertEqual(reloaded.template(for: .sentenceExplanation)?.body, "Custom sentence prompt for {{text}}")
  }
}
```

- [ ] **Step 2: Run prompt store tests and verify failure**

Run: `swift test --filter PromptStoreTests`

Expected: FAIL because `UserDefaultsPromptStore` does not exist yet.

- [ ] **Step 3: Add UserDefaults prompt persistence**

Modify `Sources/VocraCore/Stores/PromptStore.swift` by appending:

```swift
public final class UserDefaultsPromptStore: PromptStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let key = "promptTemplates"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if defaults.data(forKey: key) == nil {
      saveAll(InMemoryPromptStore.defaults().allTemplates())
    }
  }

  public func template(for kind: PromptKind) -> PromptTemplate? {
    loadAll().first { $0.kind == kind }
  }

  public func save(_ template: PromptTemplate) {
    var templates = loadAll()
    templates.removeAll { $0.kind == template.kind }
    templates.append(template)
    saveAll(templates)
  }

  public func allTemplates() -> [PromptTemplate] {
    loadAll().sorted { $0.kind.rawValue < $1.kind.rawValue }
  }

  private func loadAll() -> [PromptTemplate] {
    guard
      let data = defaults.data(forKey: key),
      let templates = try? JSONDecoder().decode([PromptTemplate].self, from: data)
    else {
      return InMemoryPromptStore.defaults().allTemplates()
    }
    return templates
  }

  private func saveAll(_ templates: [PromptTemplate]) {
    guard let data = try? JSONEncoder().encode(templates) else { return }
    defaults.set(data, forKey: key)
  }
}
```

Modify `InMemoryPromptStore` in the same file by adding:

```swift
public func allTemplates() -> [PromptTemplate] {
  PromptKind.allCases.compactMap { templates[$0] }
}
```

- [ ] **Step 4: Replace in-memory prompt store in app model**

Modify `Sources/Vocra/App/AppModel.swift`:

```swift
private let promptStore: UserDefaultsPromptStore
```

In `init()`, replace:

```swift
self.promptStore = .defaults()
```

with:

```swift
self.promptStore = UserDefaultsPromptStore()
```

- [ ] **Step 5: Replace settings view with API and prompt editors**

Replace `Sources/Vocra/Views/SettingsView.swift` with:

```swift
import SwiftUI
import VocraCore

struct SettingsView: View {
  private let settingsStore = UserDefaultsSettingsStore()
  private let apiKeyStore = KeychainAPIKeyStore()
  private let promptStore = UserDefaultsPromptStore()

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
    settingsStore.saveAPIConfiguration(APIConfiguration(baseURL: url, model: model, temperature: temperature, timeoutSeconds: timeout))
    try? apiKeyStore.saveAPIKey(apiKey)
    statusMessage = "API settings saved."
  }

  private func savePrompts() {
    promptStore.save(PromptTemplate(kind: .wordExplanation, body: wordPrompt))
    promptStore.save(PromptTemplate(kind: .phraseExplanation, body: phrasePrompt))
    promptStore.save(PromptTemplate(kind: .sentenceExplanation, body: sentencePrompt))
    promptStore.save(PromptTemplate(kind: .vocabularyCard, body: cardPrompt))
    statusMessage = "Prompts saved."
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
```

- [ ] **Step 6: Run prompt store tests**

Run: `swift test --filter PromptStoreTests`

Expected: PASS.

- [ ] **Step 7: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/VocraCore/Stores/PromptStore.swift Tests/VocraCoreTests/PromptStoreTests.swift Sources/Vocra/App/AppModel.swift Sources/Vocra/Views/SettingsView.swift
git commit -m "feat: persist custom prompts"
```

## Task 13: Daily Review Reminder

**Files:**
- Create: `Sources/VocraCore/Services/ReviewReminderService.swift`
- Modify: `Sources/Vocra/App/AppModel.swift`
- Modify: `Sources/Vocra/Views/SettingsView.swift`

- [ ] **Step 1: Add reminder service**

Write `Sources/VocraCore/Services/ReviewReminderService.swift`:

```swift
import Foundation
import UserNotifications

public struct ReviewReminderService: Sendable {
  public init() {}

  public func requestAuthorization() async throws -> Bool {
    try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
  }

  public func scheduleDailyReminder(hour: Int, minute: Int, dueCount: Int) async throws {
    let content = UNMutableNotificationContent()
    content.title = "Vocra Review"
    content.body = dueCount > 0 ? "You have \(dueCount) vocabulary cards due today." : "Open Vocra to review today's vocabulary."
    content.sound = .default

    var date = DateComponents()
    date.hour = hour
    date.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
    let request = UNNotificationRequest(identifier: "vocra.daily-review", content: content, trigger: trigger)
    try await UNUserNotificationCenter.current().add(request)
  }

  public func cancelDailyReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["vocra.daily-review"])
  }
}
```

- [ ] **Step 2: Add reminder state to settings UI**

Modify `Sources/Vocra/Views/SettingsView.swift` with state:

```swift
@State private var dailyReminderEnabled = false
@State private var reminderHour = 9
@State private var reminderMinute = 0
```

Add this section inside `Form`:

```swift
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
```

- [ ] **Step 3: Add reminder scheduling action**

Add these properties and functions to `SettingsView`:

```swift
private let reminderService = ReviewReminderService()

private func saveReminderPreference() async {
  if dailyReminderEnabled {
    do {
      let granted = try await reminderService.requestAuthorization()
      guard granted else {
        statusMessage = "Notification permission was not granted."
        return
      }
      try await reminderService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute, dueCount: 0)
      statusMessage = "Daily reminder scheduled."
    } catch {
      statusMessage = "Could not schedule reminder: \(error)"
    }
  } else {
    reminderService.cancelDailyReminder()
    statusMessage = "Daily reminder disabled."
  }
}
```

- [ ] **Step 4: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VocraCore/Services/ReviewReminderService.swift Sources/Vocra/Views/SettingsView.swift
git commit -m "feat: add review reminder service"
```

## Task 14: End-To-End Verification

**Files:**
- Modify only files needed to fix compiler, test, or runtime failures found by verification.

- [ ] **Step 1: Run all unit tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 2: Build and launch the app bundle**

Run: `./script/build_and_run.sh --verify`

Expected: PASS and `Vocra` process is running.

- [ ] **Step 3: Manual shortcut check**

Use these exact steps:

1. Open TextEdit.
2. Type `context window`.
3. Select the text.
4. Press the configured default shortcut `Option-Space`.
5. If Accessibility permission is missing, grant it in System Settings and retry.
6. Verify the panel opens.
7. Verify the panel mode is `Term`.

- [ ] **Step 4: Manual sentence check**

Use these exact steps:

1. Open TextEdit.
2. Type `The model failed to follow the instruction.`
3. Select the sentence.
4. Press `Option-Space`.
5. Verify the panel mode is `Sentence`.
6. Use the segmented control to switch to `Term`.
7. Verify a new request begins or an error is shown if the API key is missing.

- [ ] **Step 5: Manual review check**

Use these exact steps:

1. Add a word or phrase through the panel.
2. Open the main Vocra window.
3. Open the Review tab.
4. Click the card to reveal the Markdown back.
5. Click `Mastered`.
6. Verify the card no longer appears in due cards.

- [ ] **Step 6: Commit verification fixes**

If verification required code changes:

```bash
git add Sources Tests script .codex
git commit -m "fix: stabilize MVP verification"
```

If no code changes were needed, do not create an empty commit.

## Plan Self-Review

Spec coverage:

- Global shortcut: Task 8 and Task 9.
- Selected text capture: Task 8.
- Local word/phrase/sentence classification: Task 2.
- OpenAI-compatible API settings and client: Task 4 and Task 5.
- Prompt customization infrastructure: Task 3 and Task 12.
- Automatic word/phrase collection: Task 9.
- SQLite vocabulary storage: Task 7.
- Review scheduling and review UI: Task 6 and Task 11.
- Optional daily reminder: Task 13.
- Liquid Glass floating panel: Task 10.
- macOS 26 Swift/SwiftUI native app shell: Task 1.

Type consistency:

- `ExplanationMode` is used by `CapturedText`, `PromptContext`, `TextClassifier`, and `ExplanationPanelView`.
- `VocabularyType`, `VocabularyStatus`, `ReviewRating`, and `VocabularyCard` are defined before repository and review UI tasks.
- `APIConfiguration`, `AIClient`, and `OpenAICompatibleClient` signatures match the app model usage.
- `SQLiteVocabularyRepository` exposes `upsert`, `allCards`, `dueCards`, and `applyReview`, matching app model usage.

Verification:

- Pure logic has XCTest coverage.
- Platform and permission-heavy behavior is verified through `swift build`, `./script/build_and_run.sh --verify`, and manual checks.
