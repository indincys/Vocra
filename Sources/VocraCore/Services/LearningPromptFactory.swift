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
      surroundingContext: captured.surroundingContext,
      createdAt: createdAt
    )
    let rendered = try renderer.render(template, context: context)
    let contextBlock = captured.surroundingContext.isEmpty ? "" : """


    Surrounding context (the selection appears inside this text — use it only to disambiguate meaning in context; do NOT translate or analyze the context itself):
    \"\"\"
    \(captured.surroundingContext)
    \"\"\"
    """
    return """
    \(rendered)\(contextBlock)

    Contract:
    - Return exactly one single JSON object.
    - Do not wrap JSON in Markdown code fences.
    - Do not add commentary before or after the JSON.
    - Keep every object field as a JSON object, never as a string summary.
    - Keep every list field as a JSON array; use [] when there are no items.
    - explanationDepth: \(preferences.explanationDepth.rawValue)
    - exampleCount: \(preferences.exampleCount)
    - chineseStyle: \(preferences.chineseStyle.rawValue)
    - diagramDensity: \(preferences.diagramDensity.rawValue)
    """
  }
}
