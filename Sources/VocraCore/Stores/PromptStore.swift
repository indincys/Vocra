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
      Analyze this English sentence for a Chinese learner and return ONE JSON object.
      Output ONLY the fields shown below — do NOT echo the original sentence, and do NOT
      add mode, sourceText, language, titles, headline, or any other field.
      Generate the fields in exactly the order shown (translation first, then the trunk,
      then the segments) so the reader sees the meaning and skeleton first.

      {
        "sentenceAnalysis": {
          "translation": { "text": "<Chinese translation>" },
          "structureBreakdown": {
            "trunk": "<只保留主干后的核心句：主语 + 谓语 (+ 宾语/表语)，去掉所有定语、状语和从句>",
            "trunkZh": "<trunk 的简洁中文意思>",
            "items": [
              { "id": "main-clause", "text": "<exact clause span>", "labelZh": "主句", "note": "<这个分句在本句里承担的具体作用：陈述/让步/条件/原因等>", "children": [] }
            ]
          },
          "sentence": {
            "segments": [
              { "id": "main-subject", "text": "<exact contiguous substring of the sentence>", "labelZh": "主语", "color": "blue", "note": "<这一成分在本句中的具体作用：修饰/引出/连接了什么，以及在这句话里的含义>" }
            ]
          },
          "logicSummary": { "points": ["<Chinese explanation point>"], "coreMeaning": "<Chinese core meaning>" }
        }
      }

      Segment color must be one of: blue, green, orange, purple, pink, neutral.
      segment.text MUST be an exact, contiguous substring of the original sentence (copy the words and spacing verbatim) so the app can underline it; never rewrite, merge non-adjacent words, or drop words. Mark the backbone densely (subject, predicate/verb, object, complement, key adverbials, connectives, clause boundaries); minor filler may be left unmarked. Group roles by color: subject=blue, predicate/object=green, adverbial/conjunction=orange, clause/connector=purple, contrast (but / yet)=pink, minor=neutral, with a matching labelZh (主语/谓语/宾语/状语/连词/定语从句/主句…).
      Every segment and structureBreakdown item MUST include a "note" that is specific to THIS sentence (what it modifies, introduces, connects, or contrasts, and its meaning here) — teach it like a tutor, not a generic textbook definition. Keep every note ≤ 40 Chinese characters.
      structureBreakdown.trunk is the sentence stripped to its core so the learner sees the skeleton; trunkZh is its short Chinese meaning.
      Use 3-8 segments for diagramDensity full, and 1-4 for diagramDensity simple.
      Sentence: {{text}}
      """
    ),
    PromptTemplate(
      kind: .wordExplanationSchema,
      body: """
      Explain this English {{type}} for a Chinese learner and return ONE JSON object.
      Output ONLY the wordExplanation object below — do NOT add mode, sourceText,
      language, or any other top-level field.

      {
        "wordExplanation": {
          "term": "<selected word or phrase>",
          "pronunciation": "<IPA, or null>",
          "partOfSpeech": "<part of speech or phrase type>",
          "coreMeaning": "<Chinese core meaning>",
          "contextualMeaning": "<Chinese contextual meaning>",
          "usageNotes": ["<Chinese usage note, ≤40字>"],
          "collocations": ["<common collocation>"],
          "examples": [
            { "sentence": "<English example sentence>", "translation": "<Chinese translation>", "note": null }
          ],
          "commonMistakes": ["<Chinese common mistake, ≤40字>"]
        }
      }

      If pronunciation is not useful for a phrase, use null. Keep examples as objects with sentence, translation, and note; note may be null or a short Chinese string. Keep each usageNote and commonMistake ≤ 40 Chinese characters.
      Text: {{text}}
      """
    ),
    PromptTemplate(
      kind: .sentenceSupplementSchema,
      body: """
      For this English sentence, return ONE JSON object with only a relationship diagram
      and key vocabulary for a Chinese learner. Output ONLY the fields shown below.

      {
        "sentenceAnalysis": {
          "relationshipDiagram": {
            "nodes": [
              { "id": "main", "title": "主句（主干）", "text": "<main clause>" },
              { "id": "modifier", "title": "修饰/条件", "text": "<modifier or clause>" }
            ],
            "edges": [
              { "from": "modifier", "to": "main", "labelZh": "在这种情境下" }
            ]
          },
          "keyVocabulary": [
            { "term": "<important word or phrase>", "meaning": "<Chinese meaning>", "note": "<Chinese usage note, ≤40字>" }
          ]
        }
      }

      Use 2-5 nodes capturing the sentence's main parts. Every edge has from and to referencing node ids, plus a Chinese labelZh describing how they relate. keyVocabulary lists the 2-5 most useful words/phrases from the sentence; keep each note ≤ 40 Chinese characters.
      Sentence: {{text}}
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
      // Every earlier Vocra-bundled structured sentence default echoed the source
      // sentence as `"sentence": { "text": ... }`; the current default no longer does.
      // Matching that echo upgrades both the pre-trunk and trunk-era bundled defaults for
      // users who never hand-edited the template.
      normalizedBody.contains("Use exactly this root shape and JSON value types")
        && normalizedBody.contains(#""sentence": { "text": "<selected sentence>", "segments": ["#)
        && normalizedBody.contains("Segment colors must be one of")
    case .wordExplanationSchema:
      // The previous structured word default echoed the full envelope (a null
      // vocabularyCard sibling); the current default omits it.
      normalizedBody.contains("Use exactly this root shape and JSON value types")
        && normalizedBody.contains(#""wordExplanation": {"#)
        && normalizedBody.contains(#""vocabularyCard": null"#)
    case .vocabularyCardSchema, .sentenceSupplementSchema:
      false
    }
  }
}
