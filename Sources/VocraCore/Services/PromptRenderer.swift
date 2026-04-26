import Foundation

public enum PromptRenderError: Error, Equatable, Sendable {
  case unknownVariable(String)
  case malformedVariable(String)
}

public struct PromptRenderer: Sendable {
  public init() {}

  public func render(_ template: PromptTemplate, context: PromptContext) throws -> String {
    let variablePattern = #/\{\{([^}]*)\}\}/#
    let supportedVariablePattern = #/^[A-Za-z0-9_]+$/#
    let values: [String: String] = [
      "text": context.text,
      "type": context.type.rawValue,
      "sourceApp": context.sourceApp ?? "Unknown App",
      "surroundingContext": context.surroundingContext,
      "createdAt": context.createdAt
    ]

    let matches = template.body.matches(of: variablePattern)
    var output = ""
    var currentIndex = template.body.startIndex
    for match in matches {
      output += template.body[currentIndex..<match.range.lowerBound]

      let name = String(match.1)
      guard name.wholeMatch(of: supportedVariablePattern) != nil else {
        throw PromptRenderError.malformedVariable(name)
      }
      guard let value = values[name] else {
        throw PromptRenderError.unknownVariable(name)
      }
      output += value
      currentIndex = match.range.upperBound
    }
    output += template.body[currentIndex...]

    return output
  }
}
