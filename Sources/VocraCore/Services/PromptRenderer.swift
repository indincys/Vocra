import Foundation

public enum PromptRenderError: Error, Equatable, Sendable {
  case unknownVariable(String)
}

public struct PromptRenderer: Sendable {
  public init() {}

  public func render(_ template: PromptTemplate, context: PromptContext) throws -> String {
    let variablePattern = #/\{\{([A-Za-z0-9_]+)\}\}/#
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
