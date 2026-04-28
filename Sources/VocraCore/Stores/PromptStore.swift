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
    InMemoryPromptStore(templates: Dictionary(uniqueKeysWithValues: BundledPromptTemplates.current.map { ($0.kind, $0) }))
  }

  public func template(for kind: PromptKind) -> PromptTemplate? {
    templates[kind]
  }

  public mutating func save(_ template: PromptTemplate) {
    templates[template.kind] = template
  }

  public func allTemplates() -> [PromptTemplate] {
    PromptKind.allCases.compactMap { templates[$0] }
  }
}

public final class UserDefaultsPromptStore: PromptStore, @unchecked Sendable {
  private let defaults: UserDefaults
  private let key = "vocra.promptTemplates"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if defaults.data(forKey: key) == nil {
      saveAll(InMemoryPromptStore.defaults().allTemplates())
    }
  }

  public func template(for kind: PromptKind) -> PromptTemplate? {
    let templates = loadAll()
    return templates.first { $0.kind == kind }
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
    let defaultTemplates = InMemoryPromptStore.defaults().allTemplates()
    guard let data = defaults.data(forKey: key) else {
      return defaultTemplates
    }

    guard let records = try? JSONDecoder().decode([PersistedPromptTemplate].self, from: data) else {
      saveAll(defaultTemplates)
      return defaultTemplates
    }

    var templatesByKind = Dictionary(uniqueKeysWithValues: defaultTemplates.map { ($0.kind, $0) })
    var needsMigration = records.count != PromptKind.allCases.count
    for record in records {
      guard let kind = PromptKind(rawValue: record.kind) else {
        needsMigration = true
        continue
      }
      if BundledPromptTemplates.isLegacyBundledDefault(kind: kind, body: record.body) {
        needsMigration = true
        continue
      }
      templatesByKind[kind] = PromptTemplate(kind: kind, body: record.body)
    }

    let templates = PromptKind.allCases.compactMap { templatesByKind[$0] }
    if needsMigration || Set(records.map(\.kind)) != Set(PromptKind.allCases.map(\.rawValue)) {
      saveAll(templates)
    }
    return templates
  }

  private func saveAll(_ templates: [PromptTemplate]) {
    guard let data = try? JSONEncoder().encode(templates) else { return }
    defaults.set(data, forKey: key)
  }
}

private struct PersistedPromptTemplate: Codable {
  var kind: String
  var body: String
}

private enum BundledPromptTemplates {
  static let current: [PromptTemplate] = [
    PromptTemplate(
      kind: .sentenceAnalysisSchema,
      body: """
      Return a single JSON object for a deep Chinese learning analysis of this English sentence.
      Use exactly this root shape and JSON value types. Do not replace nested objects with strings.

      Required root shape:
      {
        "schemaVersion": 1,
        "mode": "sentence",
        "sourceText": "<selected text>",
        "language": { "source": "en", "explanation": "zh-Hans" },
        "sentenceAnalysis": {
          "headline": { "title": "例句解析", "subtitle": "Sentence Analysis" },
          "sentence": { "text": "<selected sentence>", "segments": [
            { "id": "main-subject", "text": "<exact sentence span>", "role": "subject", "labelZh": "主语", "labelEn": "Subject", "color": "blue" }
          ] },
          "structureBreakdown": {
            "title": "从句结构解析",
            "items": [
              { "id": "main-clause", "text": "<exact sentence span>", "role": "mainClause", "labelZh": "主句", "labelEn": "Main Clause", "children": [] }
            ]
          },
          "relationshipDiagram": {
            "nodes": [
              { "id": "main", "title": "主句（主干）", "text": "<main clause>" },
              { "id": "modifier", "title": "修饰/条件", "text": "<modifier or clause>" }
            ],
            "edges": [
              { "from": "modifier", "to": "main", "labelZh": "在这种情境下", "labelEn": "condition / context" }
            ]
          },
          "logicSummary": { "title": "句子逻辑与核心含义", "points": ["<Chinese explanation point>"], "coreMeaning": "<Chinese core meaning>" },
          "translation": { "title": "例句翻译", "text": "<Chinese translation>" },
          "keyVocabulary": [
            { "term": "<important word or phrase>", "meaning": "<Chinese meaning>", "note": "<Chinese usage note>" }
          ]
        },
        "wordExplanation": null,
        "vocabularyCard": null,
        "warnings": []
      }

      Segment colors must be one of: blue, green, orange, purple, pink, neutral.
      Every relationshipDiagram edge must include from, to, labelZh, and labelEn.
      Use 3-8 sentence.segments for diagramDensity full, and 1-4 segments for diagramDensity simple.
      Text: {{text}}
      Source app: {{sourceApp}}
      Created at: {{createdAt}}
      """
    ),
    PromptTemplate(
      kind: .wordExplanationSchema,
      body: """
      Return a single JSON object for a deep Chinese explanation of this English {{type}}.
      Use exactly this root shape and JSON value types. Do not replace nested objects or arrays with strings.

      Required root shape:
      {
        "schemaVersion": 1,
        "mode": "{{type}}",
        "sourceText": "<selected text>",
        "language": { "source": "en", "explanation": "zh-Hans" },
        "sentenceAnalysis": null,
        "wordExplanation": {
          "term": "<selected word or phrase>",
          "pronunciation": null,
          "partOfSpeech": "<part of speech or phrase type>",
          "coreMeaning": "<Chinese core meaning>",
          "contextualMeaning": "<Chinese contextual meaning>",
          "usageNotes": ["<Chinese usage note>"],
          "collocations": ["<common collocation>"],
          "examples": [
            { "sentence": "<English example sentence>", "translation": "<Chinese translation>", "note": null }
          ],
          "commonMistakes": ["<Chinese common mistake>"]
        },
        "vocabularyCard": null,
        "warnings": []
      }

      If pronunciation is not useful for a phrase, use null. Keep examples as objects with sentence, translation, and note; note may be null or a non-empty Chinese string.
      Text: {{text}}
      Source app: {{sourceApp}}
      Created at: {{createdAt}}
      """
    ),
    PromptTemplate(
      kind: .vocabularyCardSchema,
      body: """
      Return a single JSON object for a structured vocabulary review card.
      Use exactly this root shape and JSON value types. Do not replace nested objects or arrays with strings.

      Required root shape:
      {
        "schemaVersion": 1,
        "mode": "{{type}}",
        "sourceText": "<selected text>",
        "language": { "source": "en", "explanation": "zh-Hans" },
        "sentenceAnalysis": null,
        "wordExplanation": null,
        "vocabularyCard": {
          "front": { "text": "<selected word or phrase>", "hint": "<short hint or null>" },
          "back": {
            "coreMeaning": "<Chinese core meaning>",
            "memoryNote": "<Chinese memory note>",
            "usage": "<Chinese usage explanation>"
          },
          "examples": [
            { "sentence": "<English example sentence>", "translation": "<Chinese translation>" }
          ],
          "reviewPrompts": ["<review question>"]
        },
        "warnings": []
      }

      Text: {{text}}
      Source app: {{sourceApp}}
      Created at: {{createdAt}}
      """
    )
  ]

  private static let legacyDefaults: [PromptKind: String] = [
    .sentenceAnalysisSchema: """
    Return a single JSON object for a deep Chinese learning analysis of this English sentence.
    The object must match LearningExplanationDocument schemaVersion 1.
    Use mode "sentence".
    Include sentenceAnalysis with headline, sentence.segments, structureBreakdown, relationshipDiagram, logicSummary, translation, and keyVocabulary.
    Do not include Markdown fences or prose outside JSON.
    Text: {{text}}
    Source app: {{sourceApp}}
    Created at: {{createdAt}}
    """,
    .wordExplanationSchema: """
    Return a single JSON object for a deep Chinese explanation of this English {{type}}.
    The object must match LearningExplanationDocument schemaVersion 1.
    Use mode "{{type}}" and populate wordExplanation.
    Include term, pronunciation when useful, partOfSpeech, coreMeaning, contextualMeaning, usageNotes, collocations, examples, and commonMistakes.
    Do not include Markdown fences or prose outside JSON.
    Text: {{text}}
    Source app: {{sourceApp}}
    Created at: {{createdAt}}
    """,
    .vocabularyCardSchema: """
    Return a single JSON object for a structured vocabulary review card.
    The object must match LearningExplanationDocument schemaVersion 1.
    Use mode "{{type}}" and populate vocabularyCard.
    Include front, back, examples, and reviewPrompts.
    Do not include Markdown fences or prose outside JSON.
    Text: {{text}}
    Source app: {{sourceApp}}
    Created at: {{createdAt}}
    """
  ]

  static func isLegacyBundledDefault(kind: PromptKind, body: String) -> Bool {
    guard let legacy = legacyDefaults[kind] else { return false }
    let normalizedBody = normalized(body)
    if normalizedBody == normalized(legacy) {
      return true
    }
    return isPreviousStructuredBundledDefault(kind: kind, normalizedBody: normalizedBody)
  }

  private static func normalized(_ body: String) -> String {
    body
      .replacingOccurrences(of: "\r\n", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func isPreviousStructuredBundledDefault(kind: PromptKind, normalizedBody: String) -> Bool {
    switch kind {
    case .sentenceAnalysisSchema:
      normalizedBody.contains("Use exactly this root shape and JSON value types")
        && normalizedBody.contains(#""sentence": { "text": "<selected sentence>", "segments": ["#)
        && normalizedBody.contains(#""edges": []"#)
        && normalizedBody.contains("Segment colors must be one of")
    case .wordExplanationSchema:
      false
    case .vocabularyCardSchema:
      false
    }
  }
}
