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
