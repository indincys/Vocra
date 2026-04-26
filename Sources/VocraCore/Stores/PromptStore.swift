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
