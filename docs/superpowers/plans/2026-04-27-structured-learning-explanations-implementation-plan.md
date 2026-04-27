# Structured Learning Explanations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace model-generated Markdown explanations with validated structured JSON documents rendered by native SwiftUI learning views for sentence analysis, word/term explanation, and vocabulary review.

**Architecture:** VocraCore owns the structured document schema, validation, prompt construction, AI repair flow, copy-summary generation, and vocabulary persistence. The Vocra app target owns SwiftUI rendering and AppModel orchestration. The AI produces content-only JSON; all visual style, layout, colors, icons, and section order stay in SwiftUI.

**Tech Stack:** Swift 6.2, SwiftUI, XCTest, SQLite3, existing OpenAI-compatible chat completion client, UserDefaults, Keychain.

---

## Scope Check

The approved spec covers several tightly coupled parts of one feature: schema, AI output contract, validation, persistence, settings, and rendering. Keep it as one implementation plan because the app cannot safely switch to structured explanations unless these pieces ship together. The tasks below keep commits small and leave the app compiling after each task.

Phrase/term handling: the existing app has `ExplanationMode.phrase`. Treat phrase as a term explanation that uses the `wordExplanation` branch and word-style learning view, with the root document `mode` remaining `.phrase`.

## File Structure

Create:

- `Sources/VocraCore/Models/LearningExplanationDocument.swift`: Codable structured document schema and semantic color token.
- `Sources/VocraCore/Models/LearningPreferences.swift`: normal-user learning controls compiled into schema prompts.
- `Sources/VocraCore/Services/LearningExplanationValidator.swift`: schema-version, mode, source-text, branch, ID, and layout-safety validation.
- `Sources/VocraCore/Services/LearningPromptFactory.swift`: compiles schema prompts from templates, captured text, and learning preferences.
- `Sources/VocraCore/Services/StructuredExplanationService.swift`: AI request, JSON decode, validation, one repair retry.
- `Sources/VocraCore/Services/LearningExplanationSummaryRenderer.swift`: local plain-text copy summaries from validated documents.
- `Tests/VocraCoreTests/LearningExplanationDocumentTests.swift`
- `Tests/VocraCoreTests/LearningExplanationValidatorTests.swift`
- `Tests/VocraCoreTests/LearningPromptFactoryTests.swift`
- `Tests/VocraCoreTests/StructuredExplanationServiceTests.swift`
- `Tests/VocraCoreTests/LearningExplanationSummaryRendererTests.swift`
- `Sources/Vocra/Views/LearningExplanationViews.swift`: shared SwiftUI sections and mode routing.
- `Sources/Vocra/Views/SentenceLearningView.swift`
- `Sources/Vocra/Views/WordLearningView.swift`
- `Sources/Vocra/Views/VocabularyCardLearningView.swift`
- `Tests/VocraTests/LearningExplanationViewRoutingTests.swift`

Modify:

- `Sources/VocraCore/Models/PromptTemplate.swift`: replace Markdown prompt kinds with schema prompt kinds.
- `Sources/VocraCore/Stores/PromptStore.swift`: new default schema prompts.
- `Sources/VocraCore/Stores/SettingsStore.swift`: persist learning preferences.
- `Sources/VocraCore/Models/VocabularyCard.swift`: replace `cardMarkdown` with `cardJSON`.
- `Sources/VocraCore/Stores/VocabularyRepository.swift`: reset local table to structured schema version and persist `cardJSON`.
- `Sources/Vocra/App/AppModel.swift`: structured explanation pipeline and vocabulary-card generation.
- `Sources/Vocra/Support/ExplanationPanelPresenting.swift`: panel content carries a structured document instead of Markdown.
- `Sources/Vocra/Support/FloatingPanelController.swift`: pass structured content to the panel.
- `Sources/Vocra/Views/ExplanationPanelView.swift`: render structured learning views and structured errors.
- `Sources/Vocra/Views/ReviewView.swift`: render structured vocabulary-card backs.
- `Sources/Vocra/Views/VocabularyListView.swift`: keep list simple, no Markdown dependency.
- `Sources/Vocra/Views/SettingsView.swift`: basic learning settings and advanced schema prompts.
- Existing tests under `Tests/VocraCoreTests` and `Tests/VocraTests` that reference Markdown prompts or `cardMarkdown`.

Delete after all references are gone:

- `Sources/Vocra/Views/MarkdownWebView.swift`
- `Sources/VocraCore/Services/MarkdownHTMLRenderer.swift`
- `Tests/VocraCoreTests/MarkdownHTMLRendererTests.swift`

---

### Task 1: Add Structured Document Model

**Files:**
- Create: `Sources/VocraCore/Models/LearningExplanationDocument.swift`
- Create: `Tests/VocraCoreTests/LearningExplanationDocumentTests.swift`

- [ ] **Step 1: Write failing document decode tests**

Create `Tests/VocraCoreTests/LearningExplanationDocumentTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class LearningExplanationDocumentTests: XCTestCase {
  func testDecodesSentenceDocumentAndDefaultsUnknownColorToNeutral() throws {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "sentence",
      "sourceText": "Codex works best.",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": {
        "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
        "sentence": {
          "text": "Codex works best.",
          "segments": [
            { "id": "s1", "text": "Codex", "role": "subject", "labelZh": "主语", "labelEn": "Subject", "color": "cyan" }
          ]
        },
        "structureBreakdown": { "title": "结构解析", "items": [] },
        "relationshipDiagram": { "nodes": [], "edges": [] },
        "logicSummary": { "title": "核心含义", "points": ["Codex 是主语。"], "coreMeaning": "Codex 效果最好。" },
        "translation": { "title": "例句翻译", "text": "Codex 效果最好。" },
        "keyVocabulary": []
      },
      "wordExplanation": null,
      "vocabularyCard": null,
      "warnings": []
    }
    """

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))

    XCTAssertEqual(document.schemaVersion, 1)
    XCTAssertEqual(document.mode, .sentence)
    XCTAssertEqual(document.sentenceAnalysis?.sentence.segments.first?.color, .neutral)
  }

  func testDecodesPhraseDocumentUsingWordExplanationBranch() throws {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "phrase",
      "sourceText": "context window",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": null,
      "wordExplanation": {
        "term": "context window",
        "pronunciation": null,
        "partOfSpeech": "noun phrase",
        "coreMeaning": "上下文窗口",
        "contextualMeaning": "模型一次能参考的文本范围",
        "usageNotes": ["常用于大模型产品。"],
        "collocations": ["large context window"],
        "examples": [
          { "sentence": "This model has a large context window.", "translation": "这个模型有很大的上下文窗口。", "note": "描述能力范围。" }
        ],
        "commonMistakes": []
      },
      "vocabularyCard": null,
      "warnings": []
    }
    """

    let document = try JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))

    XCTAssertEqual(document.mode, .phrase)
    XCTAssertEqual(document.wordExplanation?.term, "context window")
  }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LearningExplanationDocumentTests
```

Expected: FAIL because `LearningExplanationDocument` is not defined.

- [ ] **Step 3: Add structured document model**

Create `Sources/VocraCore/Models/LearningExplanationDocument.swift`:

```swift
import Foundation

public struct LearningExplanationDocument: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public var schemaVersion: Int
  public var mode: ExplanationMode
  public var sourceText: String
  public var language: LearningExplanationLanguage
  public var sentenceAnalysis: SentenceAnalysis?
  public var wordExplanation: WordExplanation?
  public var vocabularyCard: StructuredVocabularyCard?
  public var warnings: [String]
}

public struct LearningExplanationLanguage: Codable, Equatable, Sendable {
  public var source: String
  public var explanation: String
}

public enum LearningColorToken: String, Codable, Equatable, Sendable {
  case blue
  case green
  case orange
  case purple
  case pink
  case neutral

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = LearningColorToken(rawValue: rawValue) ?? .neutral
  }
}

public struct SentenceAnalysis: Codable, Equatable, Sendable {
  public var headline: LearningHeadline
  public var sentence: AnalyzedSentence
  public var structureBreakdown: StructureBreakdown
  public var relationshipDiagram: RelationshipDiagram
  public var logicSummary: LogicSummary
  public var translation: TranslationBlock
  public var keyVocabulary: [KeyVocabularyItem]
}

public struct LearningHeadline: Codable, Equatable, Sendable {
  public var title: String
  public var subtitle: String
}

public struct AnalyzedSentence: Codable, Equatable, Sendable {
  public var text: String
  public var segments: [SentenceSegment]
}

public struct SentenceSegment: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var text: String
  public var role: String
  public var labelZh: String
  public var labelEn: String
  public var color: LearningColorToken
}

public struct StructureBreakdown: Codable, Equatable, Sendable {
  public var title: String
  public var items: [StructureItem]
}

public struct StructureItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var text: String
  public var role: String
  public var labelZh: String
  public var labelEn: String
  public var children: [StructureItem]
}

public struct RelationshipDiagram: Codable, Equatable, Sendable {
  public var nodes: [RelationshipNode]
  public var edges: [RelationshipEdge]
}

public struct RelationshipNode: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var title: String
  public var text: String
}

public struct RelationshipEdge: Codable, Equatable, Sendable {
  public var from: String
  public var to: String
  public var labelZh: String
  public var labelEn: String
}

public struct LogicSummary: Codable, Equatable, Sendable {
  public var title: String
  public var points: [String]
  public var coreMeaning: String
}

public struct TranslationBlock: Codable, Equatable, Sendable {
  public var title: String
  public var text: String
}

public struct KeyVocabularyItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String { term }
  public var term: String
  public var meaning: String
  public var note: String
}

public struct WordExplanation: Codable, Equatable, Sendable {
  public var term: String
  public var pronunciation: String?
  public var partOfSpeech: String
  public var coreMeaning: String
  public var contextualMeaning: String
  public var usageNotes: [String]
  public var collocations: [String]
  public var examples: [LearningExample]
  public var commonMistakes: [String]
}

public struct LearningExample: Codable, Equatable, Sendable, Identifiable {
  public var id: String { sentence }
  public var sentence: String
  public var translation: String
  public var note: String?
}

public struct StructuredVocabularyCard: Codable, Equatable, Sendable {
  public var front: VocabularyCardFront
  public var back: VocabularyCardBack
  public var examples: [VocabularyCardExample]
  public var reviewPrompts: [String]
}

public struct VocabularyCardFront: Codable, Equatable, Sendable {
  public var text: String
  public var hint: String?
}

public struct VocabularyCardBack: Codable, Equatable, Sendable {
  public var coreMeaning: String
  public var memoryNote: String
  public var usage: String
}

public struct VocabularyCardExample: Codable, Equatable, Sendable, Identifiable {
  public var id: String { sentence }
  public var sentence: String
  public var translation: String
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
swift test --filter LearningExplanationDocumentTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VocraCore/Models/LearningExplanationDocument.swift Tests/VocraCoreTests/LearningExplanationDocumentTests.swift
git commit -m "feat: add structured learning document model"
```

---

### Task 2: Add Validation and Layout Safety

**Files:**
- Create: `Sources/VocraCore/Services/LearningExplanationValidator.swift`
- Create: `Tests/VocraCoreTests/LearningExplanationValidatorTests.swift`

- [ ] **Step 1: Write failing validator tests**

Create `Tests/VocraCoreTests/LearningExplanationValidatorTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class LearningExplanationValidatorTests: XCTestCase {
  func testRejectsModeMismatch() throws {
    let document = validSentenceDocument()

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .word, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .modeMismatch(expected: .word, actual: .sentence))
    }
  }

  func testRejectsMissingActiveBranch() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis = nil

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .missingBranch("sentenceAnalysis"))
    }
  }

  func testRejectsDuplicateSegmentIDs() throws {
    var document = validSentenceDocument()
    document.sentenceAnalysis?.sentence.segments = [
      SentenceSegment(id: "dup", text: "Codex", role: "subject", labelZh: "主语", labelEn: "Subject", color: .blue),
      SentenceSegment(id: "dup", text: "works best", role: "predicate", labelZh: "谓语", labelEn: "Predicate", color: .green)
    ]

    XCTAssertThrowsError(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: "Codex works best.")) { error in
      XCTAssertEqual(error as? LearningExplanationValidationError, .duplicateID("sentence.segments", "dup"))
    }
  }

  func testAcceptsWhitespaceNormalizedSourceText() throws {
    let document = validSentenceDocument()

    XCTAssertNoThrow(try LearningExplanationValidator().validate(document, expectedMode: .sentence, expectedSourceText: " Codex   works best. "))
  }

  private func validSentenceDocument() -> LearningExplanationDocument {
    LearningExplanationDocument(
      schemaVersion: 1,
      mode: .sentence,
      sourceText: "Codex works best.",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: SentenceAnalysis(
        headline: LearningHeadline(title: "例句解析", subtitle: "Sentence Analysis"),
        sentence: AnalyzedSentence(
          text: "Codex works best.",
          segments: [
            SentenceSegment(id: "s1", text: "Codex", role: "subject", labelZh: "主语", labelEn: "Subject", color: .blue)
          ]
        ),
        structureBreakdown: StructureBreakdown(title: "结构解析", items: []),
        relationshipDiagram: RelationshipDiagram(nodes: [], edges: []),
        logicSummary: LogicSummary(title: "核心含义", points: ["Codex 是主语。"], coreMeaning: "Codex 效果最好。"),
        translation: TranslationBlock(title: "例句翻译", text: "Codex 效果最好。"),
        keyVocabulary: []
      ),
      wordExplanation: nil,
      vocabularyCard: nil,
      warnings: []
    )
  }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LearningExplanationValidatorTests
```

Expected: FAIL because `LearningExplanationValidator` is not defined.

- [ ] **Step 3: Add validator**

Create `Sources/VocraCore/Services/LearningExplanationValidator.swift`:

```swift
import Foundation

public enum LearningExplanationValidationError: Error, Equatable, CustomStringConvertible, Sendable {
  case unsupportedSchemaVersion(Int)
  case modeMismatch(expected: ExplanationMode, actual: ExplanationMode)
  case sourceTextMismatch
  case missingBranch(String)
  case duplicateID(String, String)
  case emptyRequiredField(String)

  public var description: String {
    switch self {
    case .unsupportedSchemaVersion(let version):
      "Unsupported schema version: \(version)."
    case .modeMismatch(let expected, let actual):
      "Expected mode \(expected.rawValue), got \(actual.rawValue)."
    case .sourceTextMismatch:
      "The response sourceText does not match the selected text."
    case .missingBranch(let branch):
      "Missing required branch: \(branch)."
    case .duplicateID(let scope, let id):
      "Duplicate ID in \(scope): \(id)."
    case .emptyRequiredField(let field):
      "Missing required text in \(field)."
    }
  }
}

public struct LearningExplanationValidator: Sendable {
  public init() {}

  public func validate(
    _ document: LearningExplanationDocument,
    expectedMode: ExplanationMode,
    expectedSourceText: String
  ) throws {
    guard document.schemaVersion == LearningExplanationDocument.currentSchemaVersion else {
      throw LearningExplanationValidationError.unsupportedSchemaVersion(document.schemaVersion)
    }
    guard document.mode == expectedMode else {
      throw LearningExplanationValidationError.modeMismatch(expected: expectedMode, actual: document.mode)
    }
    guard normalize(document.sourceText) == normalize(expectedSourceText) else {
      throw LearningExplanationValidationError.sourceTextMismatch
    }

    switch expectedMode {
    case .sentence:
      guard let sentenceAnalysis = document.sentenceAnalysis else {
        throw LearningExplanationValidationError.missingBranch("sentenceAnalysis")
      }
      try validateSentenceAnalysis(sentenceAnalysis)
    case .word, .phrase:
      guard let wordExplanation = document.wordExplanation else {
        throw LearningExplanationValidationError.missingBranch("wordExplanation")
      }
      try requireText(wordExplanation.term, field: "wordExplanation.term")
      try requireText(wordExplanation.coreMeaning, field: "wordExplanation.coreMeaning")
    }
  }

  public func validateVocabularyCard(
    _ document: LearningExplanationDocument,
    expectedMode: ExplanationMode,
    expectedSourceText: String
  ) throws {
    guard document.schemaVersion == LearningExplanationDocument.currentSchemaVersion else {
      throw LearningExplanationValidationError.unsupportedSchemaVersion(document.schemaVersion)
    }
    guard document.mode == expectedMode else {
      throw LearningExplanationValidationError.modeMismatch(expected: expectedMode, actual: document.mode)
    }
    guard normalize(document.sourceText) == normalize(expectedSourceText) else {
      throw LearningExplanationValidationError.sourceTextMismatch
    }
    guard let vocabularyCard = document.vocabularyCard else {
      throw LearningExplanationValidationError.missingBranch("vocabularyCard")
    }
    try requireText(vocabularyCard.front.text, field: "vocabularyCard.front.text")
    try requireText(vocabularyCard.back.coreMeaning, field: "vocabularyCard.back.coreMeaning")
  }

  private func validateSentenceAnalysis(_ analysis: SentenceAnalysis) throws {
    try requireText(analysis.headline.title, field: "sentenceAnalysis.headline.title")
    try requireText(analysis.sentence.text, field: "sentenceAnalysis.sentence.text")
    try requireUniqueIDs(analysis.sentence.segments.map(\.id), scope: "sentence.segments")
    try requireUniqueIDs(analysis.relationshipDiagram.nodes.map(\.id), scope: "relationshipDiagram.nodes")
    try validateStructureItems(analysis.structureBreakdown.items, scope: "structureBreakdown.items")
  }

  private func validateStructureItems(_ items: [StructureItem], scope: String) throws {
    try requireUniqueIDs(items.map(\.id), scope: scope)
    for item in items {
      try validateStructureItems(item.children, scope: "\(scope).\(item.id).children")
    }
  }

  private func requireUniqueIDs(_ ids: [String], scope: String) throws {
    var seen: Set<String> = []
    for id in ids {
      try requireText(id, field: "\(scope).id")
      if seen.contains(id) {
        throw LearningExplanationValidationError.duplicateID(scope, id)
      }
      seen.insert(id)
    }
  }

  private func requireText(_ text: String, field: String) throws {
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw LearningExplanationValidationError.emptyRequiredField(field)
    }
  }

  private func normalize(_ text: String) -> String {
    text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
swift test --filter LearningExplanationValidatorTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VocraCore/Services/LearningExplanationValidator.swift Tests/VocraCoreTests/LearningExplanationValidatorTests.swift
git commit -m "feat: validate structured learning explanations"
```

---

### Task 3: Replace Markdown Prompt Slots with Schema Prompts

**Files:**
- Modify: `Sources/VocraCore/Models/PromptTemplate.swift`
- Create: `Sources/VocraCore/Models/LearningPreferences.swift`
- Modify: `Sources/VocraCore/Stores/PromptStore.swift`
- Create: `Sources/VocraCore/Services/LearningPromptFactory.swift`
- Modify: `Tests/VocraCoreTests/PromptStoreTests.swift`
- Create: `Tests/VocraCoreTests/LearningPromptFactoryTests.swift`

- [ ] **Step 1: Write failing prompt tests**

Add to `Tests/VocraCoreTests/PromptStoreTests.swift`:

```swift
func testDefaultPromptStoreUsesSchemaPromptKinds() {
  let store = InMemoryPromptStore.defaults()

  XCTAssertNotNil(store.template(for: .sentenceAnalysisSchema))
  XCTAssertNotNil(store.template(for: .wordExplanationSchema))
  XCTAssertNotNil(store.template(for: .vocabularyCardSchema))
}
```

Create `Tests/VocraCoreTests/LearningPromptFactoryTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class LearningPromptFactoryTests: XCTestCase {
  func testBuildsPromptWithTextTypePreferencesAndJSONInstruction() throws {
    let template = PromptTemplate(
      kind: .sentenceAnalysisSchema,
      body: "Return JSON for {{type}}: {{text}} from {{sourceApp}} at {{createdAt}}."
    )
    let captured = CapturedText(
      originalText: "Codex works best.",
      cleanedText: "Codex works best.",
      mode: .sentence,
      sourceApp: "Safari"
    )

    let prompt = try LearningPromptFactory().prompt(
      for: captured,
      template: template,
      preferences: LearningPreferences(explanationDepth: .detailed, exampleCount: 3, chineseStyle: .teacherLike, diagramDensity: .full),
      createdAt: "2026-04-27T00:00:00Z"
    )

    XCTAssertTrue(prompt.contains("Return JSON for sentence: Codex works best."))
    XCTAssertTrue(prompt.contains("Safari"))
    XCTAssertTrue(prompt.contains("single JSON object"))
    XCTAssertTrue(prompt.contains("exampleCount: 3"))
    XCTAssertTrue(prompt.contains("diagramDensity: full"))
  }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter PromptStoreTests
swift test --filter LearningPromptFactoryTests
```

Expected: FAIL because the new prompt kinds and factory do not exist.

- [ ] **Step 3: Replace prompt kinds**

In `Sources/VocraCore/Models/PromptTemplate.swift`, replace `PromptKind` with:

```swift
public enum PromptKind: String, CaseIterable, Codable, Equatable, Sendable {
  case sentenceAnalysisSchema
  case wordExplanationSchema
  case vocabularyCardSchema
}
```

- [ ] **Step 4: Add learning preferences model**

Create `Sources/VocraCore/Models/LearningPreferences.swift`:

```swift
import Foundation

public struct LearningPreferences: Codable, Equatable, Sendable {
  public enum ExplanationDepth: String, Codable, CaseIterable, Sendable {
    case standard
    case detailed
  }

  public enum ChineseStyle: String, Codable, CaseIterable, Sendable {
    case concise
    case teacherLike
  }

  public enum DiagramDensity: String, Codable, CaseIterable, Sendable {
    case simple
    case full
  }

  public var explanationDepth: ExplanationDepth
  public var exampleCount: Int
  public var chineseStyle: ChineseStyle
  public var diagramDensity: DiagramDensity

  public init(
    explanationDepth: ExplanationDepth,
    exampleCount: Int,
    chineseStyle: ChineseStyle,
    diagramDensity: DiagramDensity
  ) {
    self.explanationDepth = explanationDepth
    self.exampleCount = exampleCount
    self.chineseStyle = chineseStyle
    self.diagramDensity = diagramDensity
  }

  public static let `default` = LearningPreferences(
    explanationDepth: .detailed,
    exampleCount: 2,
    chineseStyle: .teacherLike,
    diagramDensity: .full
  )
}
```

- [ ] **Step 5: Replace default prompt templates**

In `Sources/VocraCore/Stores/PromptStore.swift`, update `InMemoryPromptStore.defaults()`:

```swift
public static func defaults() -> InMemoryPromptStore {
  InMemoryPromptStore(templates: [
    .sentenceAnalysisSchema: PromptTemplate(
      kind: .sentenceAnalysisSchema,
      body: """
      Return a single JSON object for a deep Chinese learning analysis of this English sentence.
      The object must match LearningExplanationDocument schemaVersion 1.
      Use mode "sentence".
      Include sentenceAnalysis with headline, sentence.segments, structureBreakdown, relationshipDiagram, logicSummary, translation, and keyVocabulary.
      Do not include Markdown fences or prose outside JSON.
      Text: {{text}}
      Source app: {{sourceApp}}
      Created at: {{createdAt}}
      """
    ),
    .wordExplanationSchema: PromptTemplate(
      kind: .wordExplanationSchema,
      body: """
      Return a single JSON object for a deep Chinese explanation of this English {{type}}.
      The object must match LearningExplanationDocument schemaVersion 1.
      Use mode "{{type}}" and populate wordExplanation.
      Include term, pronunciation when useful, partOfSpeech, coreMeaning, contextualMeaning, usageNotes, collocations, examples, and commonMistakes.
      Do not include Markdown fences or prose outside JSON.
      Text: {{text}}
      Source app: {{sourceApp}}
      Created at: {{createdAt}}
      """
    ),
    .vocabularyCardSchema: PromptTemplate(
      kind: .vocabularyCardSchema,
      body: """
      Return a single JSON object for a structured vocabulary review card.
      The object must match LearningExplanationDocument schemaVersion 1.
      Use mode "{{type}}" and populate vocabularyCard.
      Include front, back, examples, and reviewPrompts.
      Do not include Markdown fences or prose outside JSON.
      Text: {{text}}
      Source app: {{sourceApp}}
      Created at: {{createdAt}}
      """
    )
  ])
}
```

- [ ] **Step 6: Add prompt factory**

Create `Sources/VocraCore/Services/LearningPromptFactory.swift`:

```swift
import Foundation

public struct LearningPromptFactory: Sendable {
  private let renderer: PromptRenderer

  public init(renderer: PromptRenderer = PromptRenderer()) {
    self.renderer = renderer
  }

  public func prompt(
    for captured: CapturedText,
    template: PromptTemplate,
    preferences: LearningPreferences = .default,
    createdAt: String = ISO8601DateFormatter().string(from: Date())
  ) throws -> String {
    let context = PromptContext(
      text: captured.cleanedText,
      type: captured.mode,
      sourceApp: captured.sourceApp,
      surroundingContext: "",
      createdAt: createdAt
    )
    let rendered = try renderer.render(template, context: context)
    return """
    \(rendered)

    Contract:
    - Return exactly one single JSON object.
    - Do not wrap JSON in Markdown code fences.
    - Do not add commentary before or after the JSON.
    - schemaVersion must be \(LearningExplanationDocument.currentSchemaVersion).
    - sourceText must equal the selected text.
    - explanationDepth: \(preferences.explanationDepth.rawValue)
    - exampleCount: \(preferences.exampleCount)
    - chineseStyle: \(preferences.chineseStyle.rawValue)
    - diagramDensity: \(preferences.diagramDensity.rawValue)
    """
  }
}
```

- [ ] **Step 7: Run prompt tests and fix renamed kinds**

Run:

```bash
swift test --filter PromptStoreTests
swift test --filter LearningPromptFactoryTests
swift test --filter PromptRendererTests
```

Expected: PASS after updating existing tests that still reference `.wordExplanation`, `.phraseExplanation`, `.sentenceExplanation`, or `.vocabularyCard` to the new schema prompt kinds.

- [ ] **Step 8: Commit**

```bash
git add Sources/VocraCore/Models/PromptTemplate.swift Sources/VocraCore/Models/LearningPreferences.swift Sources/VocraCore/Stores/PromptStore.swift Sources/VocraCore/Services/LearningPromptFactory.swift Tests/VocraCoreTests/PromptStoreTests.swift Tests/VocraCoreTests/LearningPromptFactoryTests.swift Tests/VocraCoreTests/PromptRendererTests.swift
git commit -m "feat: add schema prompt contract"
```

---

### Task 4: Add Structured AI Decode and Repair Service

**Files:**
- Create: `Sources/VocraCore/Services/StructuredExplanationService.swift`
- Create: `Sources/VocraCore/Services/LearningExplanationSummaryRenderer.swift`
- Create: `Tests/VocraCoreTests/StructuredExplanationServiceTests.swift`
- Create: `Tests/VocraCoreTests/LearningExplanationSummaryRendererTests.swift`

- [ ] **Step 1: Write failing service tests**

Create `Tests/VocraCoreTests/StructuredExplanationServiceTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class StructuredExplanationServiceTests: XCTestCase {
  func testReturnsValidatedDocumentFromAIJSON() async throws {
    let aiClient = StubAIClient(responses: [Self.validSentenceJSON])
  let service = StructuredExplanationService(aiClient: aiClient)
    let captured = CapturedText(originalText: "Codex works best.", cleanedText: "Codex works best.", mode: .sentence, sourceApp: nil)
    let template = PromptTemplate(kind: .sentenceAnalysisSchema, body: "Analyze {{text}}.")

    let document = try await service.explain(captured: captured, template: template)

    XCTAssertEqual(document.mode, .sentence)
    XCTAssertEqual(aiClient.prompts.count, 1)
  }

  func testRetriesOnceWithRepairPromptAfterInvalidJSON() async throws {
    let aiClient = StubAIClient(responses: ["not json", Self.validSentenceJSON])
    let service = StructuredExplanationService(aiClient: aiClient)
    let captured = CapturedText(originalText: "Codex works best.", cleanedText: "Codex works best.", mode: .sentence, sourceApp: nil)
    let template = PromptTemplate(kind: .sentenceAnalysisSchema, body: "Analyze {{text}}.")

    _ = try await service.explain(captured: captured, template: template)

    XCTAssertEqual(aiClient.prompts.count, 2)
    XCTAssertTrue(aiClient.prompts[1].contains("Repair the JSON"))
  }

  private static let validSentenceJSON = """
  {
    "schemaVersion": 1,
    "mode": "sentence",
    "sourceText": "Codex works best.",
    "language": { "source": "en", "explanation": "zh-Hans" },
    "sentenceAnalysis": {
      "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
      "sentence": { "text": "Codex works best.", "segments": [] },
      "structureBreakdown": { "title": "结构解析", "items": [] },
      "relationshipDiagram": { "nodes": [], "edges": [] },
      "logicSummary": { "title": "核心含义", "points": ["主干清晰。"], "coreMeaning": "Codex 效果最好。" },
      "translation": { "title": "例句翻译", "text": "Codex 效果最好。" },
      "keyVocabulary": []
    },
    "wordExplanation": null,
    "vocabularyCard": null,
    "warnings": []
  }
  """
}

private final class StubAIClient: AIClient, @unchecked Sendable {
  private let lock = NSLock()
  private var responses: [String]
  private(set) var prompts: [String] = []

  init(responses: [String]) {
    self.responses = responses
  }

  func complete(prompt: String) async throws -> String {
    lock.lock()
    prompts.append(prompt)
    let response = responses.removeFirst()
    lock.unlock()
    return response
  }
}
```

Create `Tests/VocraCoreTests/LearningExplanationSummaryRendererTests.swift`:

```swift
import XCTest
@testable import VocraCore

final class LearningExplanationSummaryRendererTests: XCTestCase {
  func testRendersSentencePlainTextSummary() {
    let document = LearningExplanationDocument(
      schemaVersion: 1,
      mode: .sentence,
      sourceText: "Codex works best.",
      language: LearningExplanationLanguage(source: "en", explanation: "zh-Hans"),
      sentenceAnalysis: SentenceAnalysis(
        headline: LearningHeadline(title: "例句解析", subtitle: "Sentence Analysis"),
        sentence: AnalyzedSentence(text: "Codex works best.", segments: []),
        structureBreakdown: StructureBreakdown(title: "结构解析", items: []),
        relationshipDiagram: RelationshipDiagram(nodes: [], edges: []),
        logicSummary: LogicSummary(title: "核心含义", points: ["主干是 Codex works best."], coreMeaning: "Codex 效果最好。"),
        translation: TranslationBlock(title: "例句翻译", text: "Codex 效果最好。"),
        keyVocabulary: []
      ),
      wordExplanation: nil,
      vocabularyCard: nil,
      warnings: []
    )

    let summary = LearningExplanationSummaryRenderer().render(document)

    XCTAssertTrue(summary.contains("Codex works best."))
    XCTAssertTrue(summary.contains("Codex 效果最好。"))
  }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter StructuredExplanationServiceTests
swift test --filter LearningExplanationSummaryRendererTests
```

Expected: FAIL because both services are missing.

- [ ] **Step 3: Add structured explanation service**

Create `Sources/VocraCore/Services/StructuredExplanationService.swift`:

```swift
import Foundation

public struct StructuredExplanationService: Sendable {
  private let aiClient: any AIClient
  private let promptFactory: LearningPromptFactory
  private let validator: LearningExplanationValidator
  private let decoder: JSONDecoder
  private let preferences: LearningPreferences

  public init(
    aiClient: any AIClient,
    promptFactory: LearningPromptFactory = LearningPromptFactory(),
    validator: LearningExplanationValidator = LearningExplanationValidator(),
    decoder: JSONDecoder = JSONDecoder(),
    preferences: LearningPreferences = .default
  ) {
    self.aiClient = aiClient
    self.promptFactory = promptFactory
    self.validator = validator
    self.decoder = decoder
    self.preferences = preferences
  }

  public func explain(captured: CapturedText, template: PromptTemplate) async throws -> LearningExplanationDocument {
    let prompt = try promptFactory.prompt(for: captured, template: template, preferences: preferences)
    let raw = try await aiClient.complete(prompt: prompt)
    do {
      return try decodeAndValidate(raw, captured: captured, validatesVocabularyCard: false)
    } catch {
      let repairedRaw = try await aiClient.complete(prompt: repairPrompt(originalPrompt: prompt, invalidResponse: raw, error: error))
      return try decodeAndValidate(repairedRaw, captured: captured, validatesVocabularyCard: false)
    }
  }

  public func vocabularyCard(captured: CapturedText, template: PromptTemplate) async throws -> LearningExplanationDocument {
    let prompt = try promptFactory.prompt(for: captured, template: template, preferences: preferences)
    let raw = try await aiClient.complete(prompt: prompt)
    do {
      return try decodeAndValidate(raw, captured: captured, validatesVocabularyCard: true)
    } catch {
      let repairedRaw = try await aiClient.complete(prompt: repairPrompt(originalPrompt: prompt, invalidResponse: raw, error: error))
      return try decodeAndValidate(repairedRaw, captured: captured, validatesVocabularyCard: true)
    }
  }

  private func decodeAndValidate(
    _ raw: String,
    captured: CapturedText,
    validatesVocabularyCard: Bool
  ) throws -> LearningExplanationDocument {
    let data = Data(raw.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    let document = try decoder.decode(LearningExplanationDocument.self, from: data)
    if validatesVocabularyCard {
      try validator.validateVocabularyCard(document, expectedMode: captured.mode, expectedSourceText: captured.cleanedText)
    } else {
      try validator.validate(document, expectedMode: captured.mode, expectedSourceText: captured.cleanedText)
    }
    return document
  }

  private func repairPrompt(originalPrompt: String, invalidResponse: String, error: Error) -> String {
    """
    Repair the JSON response so it satisfies the original contract.

    Validation error:
    \(String(describing: error))

    Original prompt:
    \(originalPrompt)

    Invalid response:
    \(invalidResponse)

    Return only the corrected single JSON object.
    """
  }
}
```

- [ ] **Step 4: Add plain-text summary renderer**

Create `Sources/VocraCore/Services/LearningExplanationSummaryRenderer.swift`:

```swift
import Foundation

public struct LearningExplanationSummaryRenderer: Sendable {
  public init() {}

  public func render(_ document: LearningExplanationDocument) -> String {
    switch document.mode {
    case .sentence:
      renderSentence(document)
    case .word, .phrase:
      renderWord(document)
    }
  }

  private func renderSentence(_ document: LearningExplanationDocument) -> String {
    guard let analysis = document.sentenceAnalysis else { return document.sourceText }
    return [
      document.sourceText,
      analysis.translation.text,
      analysis.logicSummary.coreMeaning,
      analysis.logicSummary.points.joined(separator: "\n")
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")
  }

  private func renderWord(_ document: LearningExplanationDocument) -> String {
    guard let word = document.wordExplanation else { return document.sourceText }
    return [
      word.term,
      word.coreMeaning,
      word.contextualMeaning,
      word.usageNotes.joined(separator: "\n")
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")
  }
}
```

- [ ] **Step 5: Run tests and verify they pass**

Run:

```bash
swift test --filter StructuredExplanationServiceTests
swift test --filter LearningExplanationSummaryRendererTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/VocraCore/Services/StructuredExplanationService.swift Sources/VocraCore/Services/LearningExplanationSummaryRenderer.swift Tests/VocraCoreTests/StructuredExplanationServiceTests.swift Tests/VocraCoreTests/LearningExplanationSummaryRendererTests.swift
git commit -m "feat: add structured AI explanation service"
```

---

### Task 5: Reset Vocabulary Storage to Structured Card JSON

**Files:**
- Modify: `Sources/VocraCore/Models/VocabularyCard.swift`
- Modify: `Sources/VocraCore/Stores/VocabularyRepository.swift`
- Modify: `Tests/VocraCoreTests/VocabularyRepositoryTests.swift`

- [ ] **Step 1: Update repository tests first**

Replace `cardMarkdown` usage in `Tests/VocraCoreTests/VocabularyRepositoryTests.swift` with `cardJSON`:

```swift
func testUpsertCreatesAndDeduplicatesByNormalizedText() throws {
  let repository = try SQLiteVocabularyRepository.inMemory()
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let cardJSON = #"{"schemaVersion":1,"mode":"phrase","sourceText":"Context Window","language":{"source":"en","explanation":"zh-Hans"},"sentenceAnalysis":null,"wordExplanation":null,"vocabularyCard":{"front":{"text":"Context Window","hint":null},"back":{"coreMeaning":"上下文窗口","memoryNote":"context + window","usage":"大模型上下文范围"},"examples":[],"reviewPrompts":[]},"warnings":[]}"#

  let first = try repository.upsert(text: "Context Window", type: .phrase, cardJSON: cardJSON, sourceApp: "Safari", now: now)
  let second = try repository.upsert(text: " context   window ", type: .phrase, cardJSON: cardJSON, sourceApp: "Codex", now: now)

  XCTAssertEqual(first.id, second.id)
  XCTAssertEqual(try repository.allCards().count, 1)
  XCTAssertEqual(try repository.allCards().first?.sourceApp, "Codex")
  XCTAssertEqual(try repository.allCards().first?.cardJSON, cardJSON)
}
```

Update `testDueCardsExcludeMasteredCards`:

```swift
let card = try repository.upsert(text: "embedding", type: .word, cardJSON: #"{"schemaVersion":1}"#, sourceApp: nil, now: now)
```

- [ ] **Step 2: Run repository tests and verify they fail**

Run:

```bash
swift test --filter VocabularyRepositoryTests
```

Expected: FAIL because `upsert(... cardJSON:)` and `VocabularyCard.cardJSON` do not exist.

- [ ] **Step 3: Replace `cardMarkdown` in the model**

In `Sources/VocraCore/Models/VocabularyCard.swift`, rename the stored property and initializer argument:

```swift
public var cardJSON: String
```

Initializer parameter:

```swift
cardJSON: String,
```

Assignment:

```swift
self.cardJSON = cardJSON
```

- [ ] **Step 4: Update repository protocol and implementation**

In `Sources/VocraCore/Stores/VocabularyRepository.swift`, change the protocol method:

```swift
func upsert(text: String, type: VocabularyType, cardJSON: String, sourceApp: String?, now: Date) throws -> VocabularyCard
```

Change the implementation signature and assignments:

```swift
public func upsert(text: String, type: VocabularyType, cardJSON: String, sourceApp: String?, now: Date) throws -> VocabularyCard {
  let normalized = normalize(text)
  if var existing = try card(normalizedText: normalized) {
    existing.cardJSON = cardJSON
    existing.sourceApp = sourceApp
    existing.updatedAt = now
    try save(existing, normalizedText: normalized)
    return existing
  }

  let card = VocabularyCard(
    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
    type: type,
    cardJSON: cardJSON,
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
```

- [ ] **Step 5: Reset table to schema version 2**

Replace `migrate()` in `VocabularyRepository.swift`:

```swift
private func migrate() throws {
  let version = try userVersion()
  if version < 2 {
    try database.execute("DROP TABLE IF EXISTS vocabulary_cards;")
  }
  try database.execute("""
  CREATE TABLE IF NOT EXISTS vocabulary_cards (
    id TEXT PRIMARY KEY,
    normalizedText TEXT UNIQUE NOT NULL,
    text TEXT NOT NULL,
    type TEXT NOT NULL,
    cardJSON TEXT NOT NULL,
    schemaVersion INTEGER NOT NULL,
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
  try database.execute("PRAGMA user_version = 2;")
}

private func userVersion() throws -> Int {
  let statement = try database.prepare("PRAGMA user_version;")
  defer { sqlite3_finalize(statement) }
  guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
  return Int(sqlite3_column_int(statement, 0))
}
```

Update insert/save SQL to include `cardJSON` and `schemaVersion`:

```swift
(id, normalizedText, text, type, cardJSON, schemaVersion, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
```

Update bindings:

```swift
sqlite3_bind_text(statement, 5, card.cardJSON, -1, SQLITE_TRANSIENT)
sqlite3_bind_int(statement, 6, Int32(LearningExplanationDocument.currentSchemaVersion))
bindOptionalText(statement, 7, card.sourceApp)
sqlite3_bind_double(statement, 8, card.createdAt.timeIntervalSince1970)
sqlite3_bind_double(statement, 9, card.updatedAt.timeIntervalSince1970)
bindOptionalDate(statement, 10, card.lastReviewedAt)
bindOptionalDate(statement, 11, card.nextReviewAt)
sqlite3_bind_int(statement, 12, Int32(card.reviewCount))
sqlite3_bind_text(statement, 13, card.status.rawValue, -1, SQLITE_TRANSIENT)
sqlite3_bind_int(statement, 14, Int32(card.familiarityLevel))
```

Update select and `readCard` column indexes:

```swift
SELECT id, text, type, cardJSON, sourceApp, createdAt, updatedAt, lastReviewedAt, nextReviewAt, reviewCount, status, familiarityLevel FROM vocabulary_cards
```

```swift
cardJSON: text(statement, 3),
sourceApp: optionalText(statement, 4),
createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
lastReviewedAt: optionalDate(statement, 7),
nextReviewAt: optionalDate(statement, 8),
reviewCount: Int(sqlite3_column_int(statement, 9)),
status: VocabularyStatus(rawValue: text(statement, 10))!,
familiarityLevel: Int(sqlite3_column_int(statement, 11))
```

- [ ] **Step 6: Run repository tests and full core tests**

Run:

```bash
swift test --filter VocabularyRepositoryTests
swift test --filter VocraCoreTests
```

Expected: PASS after updating any remaining `cardMarkdown` references in tests.

- [ ] **Step 7: Commit**

```bash
git add Sources/VocraCore/Models/VocabularyCard.swift Sources/VocraCore/Stores/VocabularyRepository.swift Tests/VocraCoreTests/VocabularyRepositoryTests.swift
git commit -m "feat: store structured vocabulary cards"
```

---

### Task 6: Wire AppModel to Structured Explanation Documents

**Files:**
- Modify: `Sources/Vocra/App/AppModel.swift`
- Modify: `Sources/Vocra/Support/ExplanationPanelPresenting.swift`
- Modify: `Sources/Vocra/Support/FloatingPanelController.swift`
- Modify: `Tests/VocraTests/AppModelTests.swift`

- [ ] **Step 1: Update AppModel tests first**

In `Tests/VocraTests/AppModelTests.swift`, change `ExplanationProvider` stubs to return `LearningExplanationDocument`. For word or phrase selections, also pass `vocabularyCardProvider: { captured in testVocabularyCardDocument(text: captured.cleanedText, mode: captured.mode) }` so tests never call the real API for card generation.

Add these helpers near the bottom:

```swift
private func testSentenceDocument(text: String) -> LearningExplanationDocument {
  let json = """
  {
    "schemaVersion": 1,
    "mode": "sentence",
    "sourceText": "\(text)",
    "language": { "source": "en", "explanation": "zh-Hans" },
    "sentenceAnalysis": {
      "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
      "sentence": { "text": "\(text)", "segments": [] },
      "structureBreakdown": { "title": "结构解析", "items": [] },
      "relationshipDiagram": { "nodes": [], "edges": [] },
      "logicSummary": { "title": "核心含义", "points": ["主干清晰。"], "coreMeaning": "核心含义。" },
      "translation": { "title": "例句翻译", "text": "译文。" },
      "keyVocabulary": []
    },
    "wordExplanation": null,
    "vocabularyCard": null,
    "warnings": []
  }
  """
  return try! JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))
}

private func testVocabularyCardDocument(text: String, mode: ExplanationMode) -> LearningExplanationDocument {
  let json = """
  {
    "schemaVersion": 1,
    "mode": "\(mode.rawValue)",
    "sourceText": "\(text)",
    "language": { "source": "en", "explanation": "zh-Hans" },
    "sentenceAnalysis": null,
    "wordExplanation": null,
    "vocabularyCard": {
      "front": { "text": "\(text)", "hint": null },
      "back": { "coreMeaning": "核心释义", "memoryNote": "记忆提示", "usage": "用法说明" },
      "examples": [],
      "reviewPrompts": []
    },
    "warnings": []
  }
  """
  return try! JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))
}
```

Update assertions:

```swift
XCTAssertEqual(panelPresenter.contents.first?.document, nil)
XCTAssertEqual(panelPresenter.contents.last?.document?.sourceText, "inconsistently")
```

For word/phrase vocabulary storage tests, use a provider that returns a word document and a vocabulary card document through separate closures in later steps.

- [ ] **Step 2: Run AppModel tests and verify they fail**

Run:

```bash
swift test --filter AppModelTests
```

Expected: FAIL because AppModel and panel content still expose Markdown.

- [ ] **Step 3: Update panel content type**

In `Sources/Vocra/Support/ExplanationPanelPresenting.swift`, replace `markdown` with:

```swift
let document: LearningExplanationDocument?
let validationErrorMessage: String?
```

Full struct:

```swift
struct ExplanationPanelContent: Equatable {
  let capturedText: CapturedText?
  let document: LearningExplanationDocument?
  let errorMessage: String?
  let validationErrorMessage: String?
}
```

In `FloatingPanelController.show`, pass:

```swift
ExplanationPanelView(
  capturedText: content.capturedText,
  document: content.document,
  errorMessage: content.errorMessage,
  validationErrorMessage: content.validationErrorMessage,
  onSwitchMode: onSwitchMode,
  onClose: onClose
)
```

- [ ] **Step 4: Update AppModel state and provider type**

In `Sources/Vocra/App/AppModel.swift`, change:

```swift
typealias ExplanationProvider = (CapturedText) async throws -> LearningExplanationDocument
typealias VocabularyCardProvider = (CapturedText) async throws -> LearningExplanationDocument
```

Replace state:

```swift
var latestDocument: LearningExplanationDocument?
var latestValidationErrorMessage: String?
```

Remove `latestMarkdown`.

In request reset:

```swift
latestErrorMessage = nil
latestValidationErrorMessage = nil
latestDocument = nil
latestCapturedText = nil
```

After explanation succeeds:

```swift
latestCapturedText = captured
latestDocument = document
latestErrorMessage = nil
latestValidationErrorMessage = nil
refreshPanel()
```

In errors that come from `LearningExplanationValidationError`, set `latestValidationErrorMessage = error.description`; for other errors, set `latestErrorMessage`.

- [ ] **Step 5: Add structured AI path and vocabulary card generation**

Add stored provider property and init parameter:

```swift
private let vocabularyCardProvider: VocabularyCardProvider?
```

Initializer parameter:

```swift
vocabularyCardProvider: VocabularyCardProvider? = nil
```

Assignment:

```swift
self.vocabularyCardProvider = vocabularyCardProvider
```

In `AppModel.explain(_:)`, map prompt kind:

```swift
let kind: PromptKind = switch captured.mode {
case .sentence: .sentenceAnalysisSchema
case .word, .phrase: .wordExplanationSchema
}
```

Build client as before and call:

```swift
let service = StructuredExplanationService(
  aiClient: OpenAICompatibleClient(
    configuration: activeProfile?.configuration ?? settingsStore.loadAPIConfiguration(),
    apiKeyProvider: { try apiKeyStore.readAPIKey() }
  )
)
return try await service.explain(captured: captured, template: template)
```

Add a private vocabulary card generator:

```swift
private func generateVocabularyCard(for captured: CapturedText) async throws -> LearningExplanationDocument {
  if let vocabularyCardProvider {
    return try await vocabularyCardProvider(captured)
  }

  let template = promptStore.template(for: .vocabularyCardSchema)!
  let activeProfile = settingsStore.loadAPIProviderSettings().activeProfile
  let apiKeyStore = activeProfile.map { KeychainAPIKeyStore(account: $0.keychainAccount) } ?? self.apiKeyStore
  let client = OpenAICompatibleClient(
    configuration: activeProfile?.configuration ?? settingsStore.loadAPIConfiguration(),
    apiKeyProvider: { try apiKeyStore.readAPIKey() }
  )
  return try await StructuredExplanationService(aiClient: client).vocabularyCard(captured: captured, template: template)
}
```

When `captured.mode == .word || captured.mode == .phrase`, call the generator and store encoded JSON:

```swift
let cardDocument = try await generateVocabularyCard(for: captured)
let cardJSON = String(data: try JSONEncoder().encode(cardDocument), encoding: .utf8)!
_ = try vocabularyRepository.upsert(
  text: captured.cleanedText,
  type: vocabularyType,
  cardJSON: cardJSON,
  sourceApp: captured.sourceApp,
  now: Date()
)
```

- [ ] **Step 6: Update refreshPanel**

Use the new content fields:

```swift
let content = ExplanationPanelContent(
  capturedText: latestCapturedText,
  document: latestDocument,
  errorMessage: latestErrorMessage,
  validationErrorMessage: latestValidationErrorMessage
)
```

- [ ] **Step 7: Run AppModel tests and fix remaining compile errors**

Run:

```bash
swift test --filter AppModelTests
```

Expected: PASS after updating all test assertions and stubs.

- [ ] **Step 8: Commit**

```bash
git add Sources/Vocra/App/AppModel.swift Sources/Vocra/Support/ExplanationPanelPresenting.swift Sources/Vocra/Support/FloatingPanelController.swift Tests/VocraTests/AppModelTests.swift
git commit -m "feat: route app explanations through structured documents"
```

---

### Task 7: Add Native Learning Explanation Views

**Files:**
- Create: `Sources/Vocra/Views/LearningExplanationViews.swift`
- Create: `Sources/Vocra/Views/SentenceLearningView.swift`
- Create: `Sources/Vocra/Views/WordLearningView.swift`
- Create: `Sources/Vocra/Views/VocabularyCardLearningView.swift`
- Modify: `Sources/Vocra/Views/ExplanationPanelView.swift`
- Create: `Tests/VocraTests/LearningExplanationViewRoutingTests.swift`

- [ ] **Step 1: Write failing routing test**

Create `Tests/VocraTests/LearningExplanationViewRoutingTests.swift`:

```swift
import XCTest
@testable import Vocra
import VocraCore

@MainActor
final class LearningExplanationViewRoutingTests: XCTestCase {
  func testPanelShowsStructuredContentWhenDocumentExists() {
    let view = ExplanationPanelView(
      capturedText: CapturedText(originalText: "Codex works best.", cleanedText: "Codex works best.", mode: .sentence),
      document: Self.sentenceDocument(),
      errorMessage: nil,
      validationErrorMessage: nil,
      onSwitchMode: { _ in },
      onClose: {}
    )

    XCTAssertNotNil(view.body)
  }

  private static func sentenceDocument() -> LearningExplanationDocument {
    let json = """
    {
      "schemaVersion": 1,
      "mode": "sentence",
      "sourceText": "Codex works best.",
      "language": { "source": "en", "explanation": "zh-Hans" },
      "sentenceAnalysis": {
        "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
        "sentence": { "text": "Codex works best.", "segments": [] },
        "structureBreakdown": { "title": "结构解析", "items": [] },
        "relationshipDiagram": { "nodes": [], "edges": [] },
        "logicSummary": { "title": "核心含义", "points": ["主干清晰。"], "coreMeaning": "Codex 效果最好。" },
        "translation": { "title": "例句翻译", "text": "Codex 效果最好。" },
        "keyVocabulary": []
      },
      "wordExplanation": null,
      "vocabularyCard": null,
      "warnings": []
    }
    """
    return try! JSONDecoder().decode(LearningExplanationDocument.self, from: Data(json.utf8))
  }
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter LearningExplanationViewRoutingTests
```

Expected: FAIL because the view initializer still takes Markdown or structured views are missing.

- [ ] **Step 3: Add shared learning view router and components**

Create `Sources/Vocra/Views/LearningExplanationViews.swift`:

```swift
import SwiftUI
import VocraCore

struct LearningExplanationView: View {
  let document: LearningExplanationDocument

  var body: some View {
    switch document.mode {
    case .sentence:
      if let analysis = document.sentenceAnalysis {
        SentenceLearningView(analysis: analysis)
      }
    case .word, .phrase:
      if let word = document.wordExplanation {
        WordLearningView(explanation: word)
      }
    }
  }
}

struct LearningSection<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.headline)
      content
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

extension LearningColorToken {
  var swiftUIColor: Color {
    switch self {
    case .blue: .blue
    case .green: .green
    case .orange: .orange
    case .purple: .purple
    case .pink: .pink
    case .neutral: .secondary
    }
  }
}

struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? 480
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX > 0, currentX + size.width > maxWidth {
        currentX = 0
        currentY += rowHeight + spacing
        rowHeight = 0
      }
      currentX += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }

    return CGSize(width: maxWidth, height: currentY + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var currentX = bounds.minX
    var currentY = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX > bounds.minX, currentX + size.width > bounds.maxX {
        currentX = bounds.minX
        currentY += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
      currentX += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
```

- [ ] **Step 4: Add sentence learning view**

Create `Sources/Vocra/Views/SentenceLearningView.swift`:

```swift
import SwiftUI
import VocraCore

struct SentenceLearningView: View {
  let analysis: SentenceAnalysis

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .center, spacing: 4) {
        Text(analysis.headline.title)
          .font(.largeTitle.bold())
        Text(analysis.headline.subtitle)
          .font(.title3.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)

      sentenceRibbon

      LearningSection(title: analysis.structureBreakdown.title, systemImage: "point.3.connected.trianglepath.dotted") {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(analysis.structureBreakdown.items) { item in
            structureItem(item)
          }
        }
      }

      LearningSection(title: "句子关系图示", systemImage: "link") {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(analysis.relationshipDiagram.edges, id: \.labelZh) { edge in
            Text("\(edge.from) → \(edge.to): \(edge.labelZh)")
          }
        }
      }

      LearningSection(title: analysis.logicSummary.title, systemImage: "lightbulb") {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(analysis.logicSummary.points, id: \.self) { point in
            Text("• \(point)")
          }
          Text(analysis.logicSummary.coreMeaning)
            .fontWeight(.semibold)
        }
      }

      LearningSection(title: analysis.translation.title, systemImage: "bubble.left.and.text.bubble.right") {
        Text(analysis.translation.text)
          .font(.title3.weight(.semibold))
      }

      LearningSection(title: "重点词汇讲解", systemImage: "book") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
          ForEach(analysis.keyVocabulary) { item in
            VStack(alignment: .leading, spacing: 6) {
              Text(item.term).font(.headline)
              Text(item.meaning).font(.subheadline).foregroundStyle(.secondary)
              Text(item.note).font(.caption)
            }
            .padding(10)
            .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
  }

  private var sentenceRibbon: some View {
    FlowLayout(spacing: 8) {
      ForEach(analysis.sentence.segments) { segment in
        VStack(spacing: 4) {
          Text(segment.text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(segment.color.swiftUIColor)
          Text(segment.labelZh)
            .font(.caption)
          Text(segment.labelEn)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(segment.color.swiftUIColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private func structureItem(_ item: StructureItem) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(item.text).font(.headline)
      Text("\(item.labelZh) / \(item.labelEn)")
        .font(.caption)
        .foregroundStyle(.secondary)
      ForEach(item.children) { child in
        structureItem(child).padding(.leading, 16)
      }
    }
  }
}
```

- [ ] **Step 5: Add word and vocabulary card views**

Create `Sources/Vocra/Views/WordLearningView.swift`:

```swift
import SwiftUI
import VocraCore

struct WordLearningView: View {
  let explanation: WordExplanation

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text(explanation.term)
          .font(.largeTitle.bold())
        if let pronunciation = explanation.pronunciation {
          Text(pronunciation)
            .font(.title3.monospaced())
            .foregroundStyle(.secondary)
        }
        Text(explanation.partOfSpeech)
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.blue.opacity(0.15), in: Capsule())
      }

      LearningSection(title: "核心含义", systemImage: "target") {
        Text(explanation.coreMeaning).font(.title3.weight(.semibold))
        Text(explanation.contextualMeaning)
      }

      LearningSection(title: "用法说明", systemImage: "text.badge.checkmark") {
        ForEach(explanation.usageNotes, id: \.self) { note in
          Text("• \(note)")
        }
      }

      LearningSection(title: "常见搭配", systemImage: "rectangle.3.group") {
        FlowLayout(spacing: 8) {
          ForEach(explanation.collocations, id: \.self) { collocation in
            Text(collocation)
              .font(.callout.weight(.semibold))
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.green.opacity(0.14), in: Capsule())
          }
        }
      }

      LearningSection(title: "例句", systemImage: "quote.bubble") {
        ForEach(explanation.examples) { example in
          VStack(alignment: .leading, spacing: 4) {
            Text(example.sentence).font(.headline)
            Text(example.translation).foregroundStyle(.secondary)
            if let note = example.note {
              Text(note).font(.caption)
            }
          }
        }
      }

      LearningSection(title: "易错点", systemImage: "exclamationmark.triangle") {
        ForEach(explanation.commonMistakes, id: \.self) { mistake in
          Text("• \(mistake)")
        }
      }
    }
  }
}
```

Create `Sources/Vocra/Views/VocabularyCardLearningView.swift`:

```swift
import SwiftUI
import VocraCore

struct VocabularyCardLearningView: View {
  let card: StructuredVocabularyCard

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      LearningSection(title: "核心释义", systemImage: "checkmark.seal") {
        Text(card.back.coreMeaning).font(.title3.weight(.semibold))
        Text(card.back.usage)
      }

      LearningSection(title: "记忆提示", systemImage: "brain") {
        Text(card.back.memoryNote)
      }

      LearningSection(title: "例句", systemImage: "quote.bubble") {
        ForEach(card.examples) { example in
          VStack(alignment: .leading, spacing: 4) {
            Text(example.sentence).font(.headline)
            Text(example.translation).foregroundStyle(.secondary)
          }
        }
      }

      LearningSection(title: "复习问题", systemImage: "questionmark.circle") {
        ForEach(card.reviewPrompts, id: \.self) { prompt in
          Text("• \(prompt)")
        }
      }
    }
  }
}
```

- [ ] **Step 6: Replace ExplanationPanelView body rendering**

In `Sources/Vocra/Views/ExplanationPanelView.swift`, replace `markdown` initializer property with:

```swift
let document: LearningExplanationDocument?
let validationErrorMessage: String?
```

Update content:

```swift
if let errorMessage {
  errorText(errorMessage, color: .red)
} else if let validationErrorMessage {
  errorText(validationErrorMessage, color: .orange)
} else if let document {
  ScrollView {
    LearningExplanationView(document: document)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
} else {
  ProgressView()
    .frame(maxWidth: .infinity, minHeight: 320)
}
```

Add helper:

```swift
private func errorText(_ message: String, color: Color) -> some View {
  ScrollView {
    Text(message)
      .foregroundStyle(color)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  .frame(minHeight: 320)
}
```

Update Copy button to copy `LearningExplanationSummaryRenderer().render(document)` when document exists.

- [ ] **Step 7: Run view tests and build**

Run:

```bash
swift test --filter LearningExplanationViewRoutingTests
swift build
```

Expected: PASS for the test and successful build.

- [ ] **Step 8: Commit**

```bash
git add Sources/Vocra/Views/LearningExplanationViews.swift Sources/Vocra/Views/SentenceLearningView.swift Sources/Vocra/Views/WordLearningView.swift Sources/Vocra/Views/VocabularyCardLearningView.swift Sources/Vocra/Views/ExplanationPanelView.swift Tests/VocraTests/LearningExplanationViewRoutingTests.swift
git commit -m "feat: render structured learning views"
```

---

### Task 8: Render Structured Review Cards

**Files:**
- Modify: `Sources/Vocra/Views/ReviewView.swift`
- Modify: `Sources/Vocra/Views/VocabularyListView.swift`
- Modify: `Tests/VocraTests/AppModelTests.swift`

- [ ] **Step 1: Add a decode helper inside ReviewView**

In `Sources/Vocra/Views/ReviewView.swift`, add:

```swift
private func decodedCard(from card: VocabularyCard) -> StructuredVocabularyCard? {
  guard
    let data = card.cardJSON.data(using: .utf8),
    let document = try? JSONDecoder().decode(LearningExplanationDocument.self, from: data)
  else {
    return nil
  }
  return document.vocabularyCard
}
```

- [ ] **Step 2: Replace Markdown back rendering**

Inside `if showsBack`, replace `MarkdownWebView` with:

```swift
if let structuredCard = decodedCard(from: card) {
  ScrollView {
    VocabularyCardLearningView(card: structuredCard)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  .frame(maxWidth: .infinity, minHeight: 220)
} else {
  Text("This card could not be decoded.")
    .foregroundStyle(.red)
}
```

- [ ] **Step 3: Keep vocabulary list independent from card body format**

In `VocabularyListView`, keep only `card.text`, `card.type`, and `card.status`. Add type text:

```swift
Text(card.type.rawValue.capitalized)
  .font(.caption)
  .foregroundStyle(.secondary)
```

- [ ] **Step 4: Run app tests and build**

Run:

```bash
swift test --filter VocraTests
swift build
```

Expected: PASS and build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/Vocra/Views/ReviewView.swift Sources/Vocra/Views/VocabularyListView.swift Tests/VocraTests/AppModelTests.swift
git commit -m "feat: show structured review cards"
```

---

### Task 9: Add Learning Settings and Advanced Schema Prompt Editing

**Files:**
- Modify: `Sources/VocraCore/Stores/SettingsStore.swift`
- Modify: `Sources/Vocra/App/AppModel.swift`
- Modify: `Sources/Vocra/Views/SettingsView.swift`
- Modify: `Tests/VocraCoreTests/SettingsStoreTests.swift`
- Modify: `Tests/VocraTests/SettingsViewTests.swift`

- [ ] **Step 1: Write failing settings-store test**

Add to `Tests/VocraCoreTests/SettingsStoreTests.swift`:

```swift
func testUserDefaultsSettingsStorePersistsLearningPreferences() throws {
  let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
  let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let store = UserDefaultsSettingsStore(defaults: defaults)
  let preferences = LearningPreferences(
    explanationDepth: .detailed,
    exampleCount: 3,
    chineseStyle: .teacherLike,
    diagramDensity: .full
  )

  store.saveLearningPreferences(preferences)

  XCTAssertEqual(store.loadLearningPreferences(), preferences)
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter SettingsStoreTests/testUserDefaultsSettingsStorePersistsLearningPreferences
```

Expected: FAIL because the settings store learning-preference methods are missing.

- [ ] **Step 3: Persist learning preferences**

In `SettingsStore` protocol, add:

```swift
func loadLearningPreferences() -> LearningPreferences
func saveLearningPreferences(_ preferences: LearningPreferences)
```

In `UserDefaultsSettingsStore`, add key:

```swift
private let learningPreferencesKey = "learningPreferences"
```

Add methods:

```swift
public func loadLearningPreferences() -> LearningPreferences {
  guard
    let data = defaults.data(forKey: learningPreferencesKey),
    let preferences = try? JSONDecoder().decode(LearningPreferences.self, from: data)
  else {
    return .default
  }
  return preferences
}

public func saveLearningPreferences(_ preferences: LearningPreferences) {
  guard let data = try? JSONEncoder().encode(preferences) else { return }
  defaults.set(data, forKey: learningPreferencesKey)
}
```

- [ ] **Step 4: Pass stored preferences to structured AI service**

In both `AppModel.explain(_:)` and `generateVocabularyCard(for:)`, initialize the service with persisted preferences:

```swift
let service = StructuredExplanationService(
  aiClient: client,
  preferences: settingsStore.loadLearningPreferences()
)
```

For the inline client construction in `explain(_:)`, the final call should be:

```swift
let client = OpenAICompatibleClient(
  configuration: activeProfile?.configuration ?? settingsStore.loadAPIConfiguration(),
  apiKeyProvider: { try apiKeyStore.readAPIKey() }
)
let service = StructuredExplanationService(
  aiClient: client,
  preferences: settingsStore.loadLearningPreferences()
)
return try await service.explain(captured: captured, template: template)
```

- [ ] **Step 5: Show basic settings and advanced prompts**

In `SettingsView`, replace the existing `Section("Prompts")` with:

```swift
Section("Learning") {
  Picker("Explanation Depth", selection: $explanationDepth) {
    Text("Standard").tag(LearningPreferences.ExplanationDepth.standard)
    Text("Detailed").tag(LearningPreferences.ExplanationDepth.detailed)
  }
  Stepper("Examples: \(exampleCount)", value: $exampleCount, in: 1...3)
  Picker("Chinese Style", selection: $chineseStyle) {
    Text("Concise").tag(LearningPreferences.ChineseStyle.concise)
    Text("Teacher-like").tag(LearningPreferences.ChineseStyle.teacherLike)
  }
  Picker("Diagram Density", selection: $diagramDensity) {
    Text("Simple").tag(LearningPreferences.DiagramDensity.simple)
    Text("Full").tag(LearningPreferences.DiagramDensity.full)
  }
  Button("Save Learning Settings", action: saveLearningSettings)
}

Section("Advanced Schema Prompts") {
  Text("Schema prompts must return the required JSON shape. Invalid output will be rejected.")
    .foregroundStyle(.secondary)
  promptEditor("Sentence Analysis Schema", text: $sentencePrompt)
  promptEditor("Word and Term Explanation Schema", text: $wordPrompt)
  promptEditor("Vocabulary Card Schema", text: $cardPrompt)
  Button("Save Schema Prompts", action: savePrompts)
}
```

Add state:

```swift
@State private var explanationDepth = LearningPreferences.ExplanationDepth.detailed
@State private var exampleCount = 2
@State private var chineseStyle = LearningPreferences.ChineseStyle.teacherLike
@State private var diagramDensity = LearningPreferences.DiagramDensity.full
```

In `load()`:

```swift
let learningPreferences = settingsStore.loadLearningPreferences()
explanationDepth = learningPreferences.explanationDepth
exampleCount = learningPreferences.exampleCount
chineseStyle = learningPreferences.chineseStyle
diagramDensity = learningPreferences.diagramDensity
```

Add save method:

```swift
private func saveLearningSettings() {
  settingsStore.saveLearningPreferences(LearningPreferences(
    explanationDepth: explanationDepth,
    exampleCount: exampleCount,
    chineseStyle: chineseStyle,
    diagramDensity: diagramDensity
  ))
  statusMessage = "Learning settings saved."
}
```

Update prompt load/save to use `.sentenceAnalysisSchema`, `.wordExplanationSchema`, and `.vocabularyCardSchema`; remove phrase prompt state and editor.

- [ ] **Step 6: Run settings tests and build**

Run:

```bash
swift test --filter SettingsStoreTests
swift test --filter SettingsViewTests
swift test --filter AppModelTests
swift build
```

Expected: PASS and build succeeds after updating tests for renamed prompt labels.

- [ ] **Step 7: Commit**

```bash
git add Sources/VocraCore/Stores/SettingsStore.swift Sources/Vocra/App/AppModel.swift Sources/Vocra/Views/SettingsView.swift Tests/VocraCoreTests/SettingsStoreTests.swift Tests/VocraTests/SettingsViewTests.swift
git commit -m "feat: add learning settings and schema prompts"
```

---

### Task 10: Remove Markdown Rendering Path and Run Full Verification

**Files:**
- Delete: `Sources/Vocra/Views/MarkdownWebView.swift`
- Delete: `Sources/VocraCore/Services/MarkdownHTMLRenderer.swift`
- Delete: `Tests/VocraCoreTests/MarkdownHTMLRendererTests.swift`
- Modify: any test or source file still referencing Markdown explanation output.

- [ ] **Step 1: Search for Markdown rendering references**

Run:

```bash
rg -n "MarkdownWebView|MarkdownHTMLRenderer|cardMarkdown|latestMarkdown|wordExplanation|phraseExplanation|sentenceExplanation|vocabularyCard" Sources Tests
```

Expected: only schema prompt names may remain where intentional. No `MarkdownWebView`, `MarkdownHTMLRenderer`, `cardMarkdown`, or `latestMarkdown` references should remain after this task.

- [ ] **Step 2: Delete Markdown renderer files**

Run:

```bash
git rm Sources/Vocra/Views/MarkdownWebView.swift Sources/VocraCore/Services/MarkdownHTMLRenderer.swift Tests/VocraCoreTests/MarkdownHTMLRendererTests.swift
```

- [ ] **Step 3: Build and test**

Run:

```bash
swift test
swift build
```

Expected: all tests pass and build succeeds.

- [ ] **Step 4: Manual app check**

Run:

```bash
script/build_and_run.sh
```

Expected:

- App launches.
- Settings window shows Learning and Advanced Schema Prompts sections.
- Selecting a sentence shows a structured learning panel.
- Selecting a word or phrase shows a word/term learning panel.
- Word or phrase capture creates a due structured vocabulary card.
- Review view shows the structured vocabulary card back without Markdown rendering.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove markdown explanation rendering"
```

---

## Self-Review Checklist

Spec coverage:

- Structured JSON replaces Markdown: Tasks 1, 3, 4, 6, 10.
- SwiftUI owns visual style: Task 7 and Task 8.
- Sentence, word/term, and vocabulary cards share the structured pipeline: Tasks 1, 4, 6, 8.
- Basic settings plus advanced schema prompts: Task 9.
- No old Markdown vocabulary migration: Task 5 resets storage to schema version 2.
- Validation and one repair retry: Task 2 and Task 4.
- Plain-text copy summary generated locally: Task 4 and Task 7.
- Tests for decode, validation, storage, routing, and settings: Tasks 1 through 10.

Type consistency:

- `LearningExplanationDocument.mode` uses existing `ExplanationMode`.
- `.phrase` uses `wordExplanation` branch and `WordLearningView`.
- Vocabulary review stores `cardJSON` and decodes `StructuredVocabularyCard`.
- Prompt kinds are `sentenceAnalysisSchema`, `wordExplanationSchema`, and `vocabularyCardSchema`.

Verification commands:

- Run focused `swift test --filter ...` commands inside each task.
- Run `swift test` and `swift build` before the final cleanup commit.
- Run `script/build_and_run.sh` for manual app verification after all code compiles.
