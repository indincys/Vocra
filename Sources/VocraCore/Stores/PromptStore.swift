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
    if let template = templates.first(where: { $0.kind == kind }) {
      return template
    }
    return templates.first { $0.kind == kind.schemaFallbackKind }
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
