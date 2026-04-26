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
