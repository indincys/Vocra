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
